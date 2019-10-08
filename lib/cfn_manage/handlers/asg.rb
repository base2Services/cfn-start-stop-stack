require 'cfn_manage/aws_credentials'

require 'aws-sdk-autoscaling'
require 'aws-sdk-ec2'
require 'aws-sdk-elasticloadbalancingv2'

module CfnManage
  module StartStopHandler
    class Asg

      def initialize(asg_id, options = {})
        @asg_name = asg_id
        @wait_state = options.has_key?(:wait_state) ? options[:wait_state] : CfnManage.asg_wait_state
        @skip_wait = options.has_key?(:skip_wait) ? options[:skip_wait] : CfnManage.skip_wait? 
        @suspend_termination = options.has_key?(:suspend_termination) ? options[:suspend_termination] : CfnManage.asg_suspend_termination?
        
        credentials = CfnManage::AWSCredentials.get_session_credentials("stopasg_#{@asg_name}")
        @asg_client = Aws::AutoScaling::Client.new(retry_limit: 20)
        @ec2_client = Aws::EC2::Client.new(retry_limit: 20)
        @elb_client = Aws::ElasticLoadBalancingV2::Client.new(retry_limit: 20)
        if credentials != nil
          @asg_client = Aws::AutoScaling::Client.new(credentials: credentials, retry_limit: 20)
          @ec2_client = Aws::EC2::Client.new(credentials: credentials, retry_limit: 20)
          @elb_client = Aws::ElasticLoadBalancingV2::Client.new(credentials: credentials, retry_limit: 20)
        end

        asg_details = @asg_client.describe_auto_scaling_groups(
            auto_scaling_group_names: [@asg_name]
        )
        if asg_details.auto_scaling_groups.size() == 0
          raise "Couldn't find ASG #{@asg_name}"
        end
        @asg = asg_details.auto_scaling_groups[0]
      end

      def stop
        # check if already stopped
        if @asg.min_size == @asg.max_size and @asg.max_size == @asg.desired_capacity and @asg.min_size == 0
          $log.info("ASG #{@asg_name} already stopped")
          # nil and false configurations are not saved
          return nil
        else

          unless @suspend_termination
            # store asg configuration to S3
            configuration = {
                desired_capacity: @asg.desired_capacity,
                min_size: @asg.min_size,
                max_size: @asg.max_size
            }

            $log.info("Setting desired capacity to 0/0/0 for ASG #{@asg.auto_scaling_group_name}A")

            @asg_client.update_auto_scaling_group({
                auto_scaling_group_name: "#{@asg.auto_scaling_group_name}",
                min_size: 0,
                max_size: 0,
                desired_capacity: 0
            })
            return configuration
          else

            configuration = {
              desired_capacity: @asg.desired_capacity,
              min_size: @asg.min_size,
              max_size: @asg.max_size,
              suspended_processes: @asg.suspended_processes
            }

            $log.info("Suspending processes for ASG #{@asg.auto_scaling_group_name}A")

            @asg_client.suspend_processes({
              auto_scaling_group_name: "#{@asg.auto_scaling_group_name}",
            })

            $log.info("Stopping all instances in ASG #{@asg.auto_scaling_group_name}A")

            @asg.instances.each do |instance|
              @instance_id = instance.instance_id
              @instance = Aws::EC2::Resource.new(client: @ec2_client, retry_limit: 20).instance(@instance_id)

              if %w(stopped stopping).include?(@instance.state.name)
                $log.info("Instance #{@instance_id} already stopping or stopped")
                return
              end

              $log.info("Stopping instance #{@instance_id}")
              @instance.stop()
            end

            return configuration

          end

        end

      end

      def start(configuration)
        if configuration.nil?
          $log.warn("No configuration found for #{@asg_name}, skipping..")
          return
        end
        $log.info("Starting ASG #{@asg_name} with following configuration\n#{configuration}")

        unless @suspend_termination
          # restore asg sizes
          @asg_client.update_auto_scaling_group({
            auto_scaling_group_name: @asg_name,
            min_size: configuration['min_size'],
            max_size: configuration['max_size'],
            desired_capacity: configuration['desired_capacity']
          })
          
        else

          $log.info("Starting instances for ASG #{@asg_name}...")

          @asg.instances.each do |instance|
            @instance_id = instance.instance_id
            @instance = Aws::EC2::Resource.new(client: @ec2_client, retry_limit: 20).instance(@instance_id)

            if %w(running).include?(@instance.state.name)
              $log.info("Instance #{@instance_id} already running")
              return
            end
            $log.info("Starting instance #{@instance_id}")
            @instance.start()
          end
          
        end
        
        if @skip_wait && @suspend_termination
          # If wait is skipped we still need to wait until the instances are healthy in the asg
          # before resuming the processes. This will avoid the asg terminating the instances.
          wait('HealthyInASG')
        elsif !@skip_wait
          # if we are waiting for the instances to reach a desired state
          $log.info("Waiting for ASG instances wait state #{@wait_state}")
          wait(@wait_state)
        end
        
        if @suspend_termination
          # resume the asg processes after we've waited for them to become healthy
          $log.info("Resuming all processes for ASG #{@asg_name}")

          @asg_client.resume_processes({
            auto_scaling_group_name: "#{@asg.auto_scaling_group_name}",
          })

          if configuration.key?(:suspended_processes)

            $log.info("Suspending processes stored in configuration for ASG #{@asg_name}")

            @asg_client.suspend_processes({
              auto_scaling_group_name: "#{@asg.auto_scaling_group_name}",
              scaling_processes: configuration['suspended_processes'],
            })
          end

        end

      end

      def wait(type)
        
        attempts = 0
        
        until attempts == (max_attempts = 60*6) do
          
          case type
          when 'HealthyInASG'
            success = wait_till_healthy_in_asg()
          when 'Running'
            success = wait_till_running()
          when 'HealthyInTargetGroup'
            success = wait_till_healthy_in_target_group()
          else
            $log.warn("unknown asg wait type #{type}. skipping...")
            break
          end
          
          if success
            break
          end
          
          attempts = attempts + 1
          sleep(15)
        end

        if attempts == max_attempts
          $log.error("Failed to wait for asg with wait type #{type}")
        end
      end
      
      def wait_till_healthy_in_asg

        asg_curr_details = @asg_client.describe_auto_scaling_groups(
          auto_scaling_group_names: [@asg_name]
        )
        
        asg_status = asg_curr_details.auto_scaling_groups.first
        health_status = asg_status.instances.collect { |inst| inst.health_status }
        
        if health_status.empty?
          $log.info("ASG #{@asg_name} has not started any instances yet")
          return false
        end
        
        if health_status.all? "Healthy"
          $log.info("All instances healthy in ASG #{@asg_name}")
          return true
        end
          
        unhealthy = @asg_status.instances.select {|inst| inst.health_status == "Unhealthy" }.collect {|inst| inst.instance_id }
        $log.info("waiting for instances #{unhealthy} to become healthy in asg #{@asg_name}")
        return false
        
      end
      
      def wait_till_running
          
        asg_curr_details = @asg_client.describe_auto_scaling_groups(
          auto_scaling_group_names: [@asg_name]
        )
        asg_status = asg_curr_details.auto_scaling_groups.first
        instances = asg_status.instances.collect { |inst| inst.instance_id }
        
        if instances.empty?
          $log.info("ASG #{@asg_name} has not started any instances yet")
          return false
        end
        
        status = @ec2_client.describe_instance_status({
          instance_ids: instances
        })
        
        state = status.instance_statuses.collect {|inst| inst.instance_state.name}
        
        if state.all? "running"
          $log.info("All instances in a running state from ASG #{@asg_name}")
          return true
        end
        
        not_running = @status.instance_statuses.select {|inst| inst.instance_state.name != "running" }
        not_running.each do |inst|
          $log.info("waiting for instances #{inst.instance_id} to be running. Current state is #{inst.instance_state.name}")
        end
        
        return false
        
      end
      
      def wait_till_healthy_in_target_group
          
        asg_curr_details = @asg_client.describe_auto_scaling_groups(
          auto_scaling_group_names: [@asg_name]
        )
        asg_status = asg_curr_details.auto_scaling_groups.first
        asg_instances = asg_status.instances.collect { |inst| inst.instance_id }
        target_groups = asg_status.target_group_arns
        
        if asg_instances.empty?
          $log.info("ASG #{@asg_name} has not started any instances yet")
          return false
        end
        
        if target_groups.empty?
          # we want to skip here if the asg is not associated with any target groups
          $log.info("ASG #{@asg_name} is not associated with any target groups")
          return true
        end
        
        target_health = []
        target_groups.each do |tg| 
          resp = @elb_client.describe_target_health({
            target_group_arn: tg, 
          })
          if resp.target_health_descriptions.length != asg_instances.length
            # we need to wait until all asg insatnces have been placed into the target group 
            # before we can check they're healthy
            $log.info("All ASG instances haven't been placed into target group #{tg.split('/')[1]} yet")
            return false
          end
          target_health.push(*resp.target_health_descriptions)
        end
              
        state = target_health.collect {|tg| tg.target_health.state}
        
        if state.all? 'healthy'
          $log.info("All instances are in a healthy state in target groups #{target_groups.map {|tg| tg.split('/')[1] }}")
          return true
        end
        
        unhealthy = target_health.select {|tg| tg.target_health.state != 'healthy'}
        unhealthy.each do |tg|
          $log.info("waiting for instances #{tg.target.id} to be healthy in target group. Current state is #{tg.target_health.state}")
        end
        
        return false
        
      end

    end
  end
end

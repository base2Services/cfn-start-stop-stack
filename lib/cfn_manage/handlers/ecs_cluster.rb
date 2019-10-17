require 'aws-sdk-ecs'
require 'cfn_manage/aws_credentials'

module CfnManage
  module StartStopHandler
    class EcsCluster

      def initialize(cluster_id, options = {})
        @wait_state = options.has_key?(:wait_state) ? options[:wait_state] : CfnManage.ecs_wait_state
        @skip_wait = options.has_key?(:skip_wait) ? CfnManage.true?(options[:skip_wait]) : CfnManage.skip_wait? 
        @wait_container_instances = options.has_key?(:wait_container_instances) ? CfnManage.true?(options[:wait_container_instances]) : CfnManage.ecs_wait_container_instances? 
        @ignore_missing_ecs_config = options.has_key?(:ignore_missing_ecs_config) ? CfnManage.true?(options[:ignore_missing_ecs_config]) : CfnManage.ignore_missing_ecs_config?
        
        credentials = CfnManage::AWSCredentials.get_session_credentials("stoprun_#{cluster_id}")
        @ecs_client = Aws::ECS::Client.new(credentials: credentials, retry_limit: 20)
        @elb_client = Aws::ElasticLoadBalancingV2::Client.new(credentials: credentials, retry_limit: 20)
        @services = []
        @ecs_client.list_services(cluster: cluster_id, scheduling_strategy: 'REPLICA', max_results: 100).each do |results|
          @services.push(*results.service_arns)
        end
        $log.info("Found #{@services.count} services in ECS cluster #{cluster_id}")
        @cluster = cluster_id
      end

      def start(configuration)
        if @wait_container_instances
          wait_for_instances()
        end
        
        @services.each do |service_arn|

          $log.info("Searching for ECS service #{service_arn} in cluster #{@cluster}")
          service = @ecs_client.describe_services(services:[service_arn], cluster: @cluster).services.first

          if service.desired_count != 0
            $log.info("ECS service #{service.service_name} is already running")
            next
          end

          if configuration.has_key?(service.service_name)
            desired_count = configuration[service.service_name]['desired_count']
          elsif CfnManage.ignore_missing_ecs_config?
            $log.info("ECS service #{service.service_name} wasn't previosly stopped by cfn_manage. Option --ignore-missing-ecs-config set and setting desired count to 1")
            desired_count = 1
          else
            $log.warn("ECS service #{service.service_name} wasn't previosly stopped by cfn_manage. Skipping ...")
            next
          end

          $log.info("Starting ECS service #{service.service_name} with desired count of #{desired_count}")
          @ecs_client.update_service({
            desired_count: desired_count,
            service: service_arn,
            cluster: @cluster
          })

        end
        
        if !@skip_wait
          @services.each do |service_arn|
            wait(@wait_state,service_arn)
          end
        end
      end

      def stop
        configuration = {}
        @services.each do |service_arn|

          $log.info("Searching for ECS service #{service_arn} in cluster #{@cluster}")
          service = @ecs_client.describe_services(services:[service_arn], cluster: @cluster).services.first

          if service.desired_count == 0
            $log.info("ECS service #{service.service_name} is already stopped")
            next
          end

          configuration[service.service_name] = { desired_count: service.desired_count }
          $log.info("Stopping ECS service #{service.service_name}")
          @ecs_client.update_service({
            desired_count: 0,
            service: service_arn,
            cluster: @cluster
          })

        end

        return configuration.empty? ? nil : configuration
      end

      def wait(type,service_arn=nil)
        
        if service_arn.nil?
          $log.warn("unable to wait for #{service_arn} service")
          return
        end
        
        attempts = 0
        
        until attempts == (max_attempts = 60*6) do
          
          case type
          when 'Running'
            success = wait_till_running(service_arn)
          when 'HealthyInTargetGroup'
            success = wait_till_healthy_in_target_group(service_arn)
          else
            $log.warn("unknown ecs service wait type #{type}. skipping...")
            break
          end
          
          if success
            break
          end
          
          attempts = attempts + 1
          sleep(15)
        end

        if attempts == max_attempts
          $log.error("Failed to wait for ecs service with wait type #{type}")
        end
      end
      
      def wait_for_instances
        
        attempts = 0
        
        until attempts == (max_attempts = 60*3) do
          
          resp = @ecs_client.list_container_instances({
            cluster: @cluster,
            status: "ACTIVE"
          })
          
          if resp.container_instance_arns.any?
            $log.info("A container instances has joined ecs cluster #{@cluster}")
            break
          end
          
          attempts = attempts + 1
          sleep(5)
        end

        if attempts == max_attempts
          $log.error("Failed to wait for container instances to join ecs cluster #{@cluster}")
        end
      end
      
      def wait_till_running(service_arn)
        service = @ecs_client.describe_services(services:[service_arn], cluster: @cluster).services.first
        
        if service.running_count > 0
          $log.info("ecs service #{service_arn} has #{service.running_count} running tasks")
        end  
        
        $log.info("waiting for ecs service #{service_arn} to reach a running state")
        return false
      end
      
      def wait_till_healthy_in_target_group(service_arn)
        service = @ecs_client.describe_services(services:[service_arn], cluster: @cluster).services.first
        target_groups = service.load_balancers.collect { |lb| lb.target_group_arn }
        
        if target_groups.empty?
          # we want to skip here if the asg is not associated with any target groups
          $log.info("ecs aervice #{service_arn} is not associated with any target groups")
          return true
        end
        
        target_health = []
        target_groups.each do |tg| 
          resp = @elb_client.describe_target_health({
            target_group_arn: tg, 
          })
          if resp.target_health_descriptions.empty?
            # we need to wait until a ecs task has been placed into the target group
            # before we can check it's healthy
            $log.info("ECS service #{service_arn} hasn't been placed into target group #{tg.split('/')[1]} yet")
            return false
          end
          target_health.push(*resp.target_health_descriptions)
        end
              
        state = target_health.collect {|tg| tg.target_health.state}
                
        if state.all? 'healthy'
          $log.info("All ecs tasks are in a healthy state in target groups #{target_groups.map {|tg| tg.split('/')[1] }}")
          return true
        end
        
        unhealthy = target_health.select {|tg| tg.target_health.state != 'healthy'}
        unhealthy.each do |tg|
          $log.info("waiting for ecs task #{tg.target.id} to be healthy in target group. Current state is #{tg.target_health.state}")
        end
        
        return false
      end

    end
  end
end

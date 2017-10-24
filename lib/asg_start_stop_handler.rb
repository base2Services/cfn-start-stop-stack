require_relative '../lib/aws_credentials'

module Base2

  class AsgStartStopHandler

    def initialize(asg_id)
      @asg_name = asg_id

      credentials = Base2::AWSCredentials.get_session_credentials("stopasg_#{@asg_name}")
      @asg_client = Aws::AutoScaling::Client.new()
      if credentials != nil
        @asg_client = Aws::AutoScaling::Client.new(credentials: credentials)
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
        # store asg configuration to S3
        configuration = {
            desired_capacity: @asg.desired_capacity,
            min_size: @asg.min_size,
            max_size: @asg.max_size
        }

        $log.info("Setting desired capacity to 0/0/0 for ASG #{@asg.auto_scaling_group_name}A")
        # set asg configuration to 0/0/0
        puts @asg.auto_scaling_group_name
        @asg_client.update_auto_scaling_group({
            auto_scaling_group_name: "#{@asg.auto_scaling_group_name}",
            min_size: 0,
            max_size: 0,
            desired_capacity: 0
        })
        return configuration
      end

    end

    def start(configuration)
      if configuration.nil?
        $log.warn("No configuration found for #{@asg_name}, skipping..")
        return
      end
      $log.info("Starting ASG #{@asg_name} with following configuration\n#{configuration}")

      # restore asg sizes
      @asg_client.update_auto_scaling_group({
          auto_scaling_group_name: @asg_name,
          min_size: configuration['min_size'],
          max_size: configuration['max_size'],
          desired_capacity: configuration['desired_capacity']
      })
    end

  end
end
require_relative '../lib/aws_credentials'

module Base2

  class Ec2StartStopHandler

    @instance

    def initialize(instance_id)
      credentials = Base2::AWSCredentials.get_session_credentials("stoprun_#{instance_id}")
      ec2_client = Aws::EC2::Client.new(credentials: credentials, retry_limit: 20)
      @instance = Aws::EC2::Resource.new(client: ec2_client, retry_limit: 20).instance(instance_id)
      @instance_id = instance_id
    end

    def start(configuration)
      if %w(running).include?(@instance.state.name)
        $log.info("Instance #{@instance_id} already running")
        return
      end
      $log.info("Starting instance #{@instance_id}")
      @instance.start()
    end

    def stop
      if %w(stopped stopping).include?(@instance.state.name)
        $log.info("Instance #{@instance_id} already stopping or stopped")
        return
      end
      $log.info("Stopping instance #{@instance_id}")
      @instance.stop()

      # empty configuration for ec2 instances
      return {}
    end




  end
end
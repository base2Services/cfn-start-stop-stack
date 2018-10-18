require_relative '../lib/aws_credentials'

module Base2

  class SpotFleetStartStopHandler

    def initialize(fleet_id, skip_wait)
      @fleet_id = fleet_id
      @skip_wait = skip_wait
      credentials = Base2::AWSCredentials.get_session_credentials("startstopfleet_#{fleet_id}")
      @ec2_client = Aws::EC2::Client.new(retry_limit: 20)
      if credentials != nil
        @ec2_client = Aws::EC2::Client.new(credentials: credentials, retry_limit: 20)
      end

      @fleet = @ec2_client.describe_spot_fleet_requests({spot_fleet_request_ids:[fleet_id]})
      @fleet = @fleet.spot_fleet_request_configs[0].spot_fleet_request_config
    end

    def start(configuration)

      $log.info("Setting fleet #{@fleet_id} capacity to #{configuration['target_capacity']}")
      @ec2_client.modify_spot_fleet_request({
          spot_fleet_request_id: @fleet_id,
          target_capacity: configuration['target_capacity'],
      })

      return configuration
    end

    def stop

      if @fleet.target_capacity == 0
        $log.info("Spot fleet #{@fleet_id} already stopped")
        return nil
      end

      configuration = {
          target_capacity: @fleet.target_capacity
      }

      $log.info("Setting fleet #{@fleet_id} capacity to 0")
      @ec2_client.modify_spot_fleet_request({
          spot_fleet_request_id: @fleet_id,
          target_capacity: 0,
      })

      return configuration
    end

    def wait(wait_states=[])
      $log.debug("Not waiting for spot fleet #{@fleet_id}")
    end

  end

end

require_relative '../lib/aws_credentials'

module Base2

  class EcsServiceStartStopHandler

    @instance

    def initialize(cluster_id)
      credentials = Base2::AWSCredentials.get_session_credentials("stoprun_#{cluster_id}")
      @ecs_client = Aws::ECS::Client.new(credentials: credentials, retry_limit: 20)
      @services = @ecs_client.list_services(cluster: cluster_id).service_arns
      $log.info("Found #{@services.count} services in ECS cluster #{cluster_id}")
      @cluster = cluster_id
    end

    def start(configuration)
      @services.each do |service_arn|

        $log.info("Searching for ECS service #{service_arn} in cluster #{@cluster}")
        service = @ecs_client.describe_services(services:[service_arn], cluster: @cluster).services[0]

        if service.desired_count != 0
          $log.info("ECS service #{service.service_name} is already running")
          next
        end

        $log.info("Starting ECS service #{service.service_name} with desired count of #{configuration[service.service_name]['desired_count']}")
        @ecs_client.update_service({
          desired_count: configuration[service.service_name]['desired_count'],
          service: service_arn,
          cluster: @cluster
        })

      end
    end

    def stop
      configuration = {}
      @services.each do |service_arn|

        $log.info("Searching for ECS service #{service_arn} in cluster #{@cluster}")
        service = @ecs_client.describe_services(services:[service_arn], cluster: @cluster).services[0]

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

      return configuration
    end




  end
end

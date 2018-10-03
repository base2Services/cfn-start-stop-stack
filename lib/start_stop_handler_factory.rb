require_relative '../lib/asg_start_stop_handler'
require_relative '../lib/ec2_start_stop_handler'
require_relative '../lib/rds_start_stop_handler'
require_relative '../lib/aurora_cluster_start_stop_handler'
require_relative '../lib/alarm_start_stop_handler'
require_relative '../lib/spot_fleet_start_stop_handler'
require_relative '../lib/ecs_service_start_stop_handler'

module Base2

  class StartStopHandlerFactory

    #   Factory method to get start/stop handler based on CloudFormation
    # resource type. If resource_id passed in does not exist, it is
    # very likely that exception will be raised
    def self.get_start_stop_handler(resource_type, resource_id)
      case resource_type
        when 'AWS::AutoScaling::AutoScalingGroup'
          return Base2::AsgStartStopHandler.new(resource_id)

        when 'AWS::EC2::Instance'
          return Base2::Ec2StartStopHandler.new(resource_id)

        when 'AWS::RDS::DBInstance'
          return Base2::RdsStartStopHandler.new(resource_id)

        when 'AWS::RDS::DBCluster'
          return Base2::AuroraClusterStartStopHandler.new(resource_id)

        when 'AWS::CloudWatch::Alarm'
          return Base2::AlarmStartStopHandler.new(resource_id)

        when 'AWS::EC2::SpotFleet'
          return Base2::SpotFleetStartStopHandler.new(resource_id)

        when 'AWS::ECS::Cluster'
          return Base2::EcsServiceStartStopHandler.new(resource_id)

        else
          return nil
      end
    end
  end
end

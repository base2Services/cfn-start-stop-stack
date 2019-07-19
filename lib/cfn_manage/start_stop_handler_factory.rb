require 'cfn_manage/asg_start_stop_handler'
require 'cfn_manage/ec2_start_stop_handler'
require 'cfn_manage/rds_start_stop_handler'
require 'cfn_manage/aurora_cluster_start_stop_handler'
require 'cfn_manage/alarm_start_stop_handler'
require 'cfn_manage/spot_fleet_start_stop_handler'
require 'cfn_manage/ecs_cluster_start_stop_handler'
require 'cfn_manage/documentdb_cluster_start_stop_handler'

module CfnManage

  class StartStopHandlerFactory

    #   Factory method to get start/stop handler based on CloudFormation
    # resource type. If resource_id passed in does not exist, it is
    # very likely that exception will be raised
    def self.get_start_stop_handler(resource_type, resource_id, skip_wait)
      case resource_type
        when 'AWS::AutoScaling::AutoScalingGroup'
          return CfnManage::AsgStartStopHandler.new(resource_id, skip_wait)

        when 'AWS::EC2::Instance'
          return CfnManage::Ec2StartStopHandler.new(resource_id, skip_wait)

        when 'AWS::RDS::DBInstance'
          return CfnManage::RdsStartStopHandler.new(resource_id, skip_wait)

        when 'AWS::RDS::DBCluster'
          return CfnManage::AuroraClusterStartStopHandler.new(resource_id, skip_wait)

        when 'AWS::DocDB::DBCluster'
          return CfnManage::DocumentDbClusterStartStopHandler.new(resource_id, skip_wait)

        when 'AWS::CloudWatch::Alarm'
          return CfnManage::AlarmStartStopHandler.new(resource_id)

        when 'AWS::EC2::SpotFleet'
          return CfnManage::SpotFleetStartStopHandler.new(resource_id, skip_wait)

        when 'AWS::ECS::Cluster'
          return CfnManage::EcsClusterStartStopHandler.new(resource_id, skip_wait)
          
        when 'AWS::Transfer::Server'
          return CfnManage::TransferStartStopHandler.new(resource_id, skip_wait)

        else
          return nil
      end
    end
  end
end

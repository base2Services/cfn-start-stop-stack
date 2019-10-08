require 'cfn_manage/handlers/asg'
require 'cfn_manage/handlers/ec2'
require 'cfn_manage/handlers/rds'
require 'cfn_manage/handlers/aurora_cluster'
require 'cfn_manage/handlers/alarm'
require 'cfn_manage/handlers/spot_fleet'
require 'cfn_manage/handlers/ecs_cluster'
require 'cfn_manage/handlers/documentdb'
require 'cfn_manage/handlers/transfer'

module CfnManage

  class StartStopHandlerFactory

    #   Factory method to get start/stop handler based on CloudFormation
    # resource type. If resource_id passed in does not exist, it is
    # very likely that exception will be raised
    def self.get_start_stop_handler(resource_type, resource_id, options)
      case resource_type
        when 'AWS::AutoScaling::AutoScalingGroup'
          return CfnManage::StartStopHandler::Asg.new(resource_id,options)

        when 'AWS::EC2::Instance'
          return CfnManage::StartStopHandler::Ec2.new(resource_id,options)

        when 'AWS::RDS::DBInstance'
          return CfnManage::StartStopHandler::Rds.new(resource_id,options)

        when 'AWS::RDS::DBCluster'
          return CfnManage::StartStopHandler::AuroraCluster.new(resource_id,options)

        when 'AWS::DocDB::DBCluster'
          return CfnManage::StartStopHandler::DocumentDb.new(resource_id,options)

        when 'AWS::CloudWatch::Alarm'
          return CfnManage::StartStopHandler::Alarm.new(resource_id,options)

        when 'AWS::EC2::SpotFleet'
          return CfnManage::StartStopHandler::SpotFleet.new(resource_id,options)

        when 'AWS::ECS::Cluster'
          return CfnManage::StartStopHandler::EcsCluster.new(resource_id,options)

        when 'AWS::Transfer::Server'
          return CfnManage::StartStopHandler::Transfer.new(resource_id,options)

        else
          return nil
      end
    end
  end
end

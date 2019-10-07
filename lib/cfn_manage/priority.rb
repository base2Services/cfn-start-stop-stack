require 'cfn_manage/aws_credentials'
require 'cfn_manage/tag_reader'
require 'cfn_manage/globals'

module CfnManage
  class Priority
      
    @defaults = {
      'AWS::RDS::DBInstance' => '100',
      'AWS::RDS::DBCluster' => '100',
      'AWS::DocDB::DBCluster' => '100',
      'AWS::AutoScaling::AutoScalingGroup' => '200',
      'AWS::EC2::Instance' => '200',
      'AWS::EC2::SpotFleet' => '200',
      'AWS::Transfer::Server' => '200',
      'AWS::ECS::Cluster' => '250',
      'AWS::CloudWatch::Alarm' => '300'
    }
  
    def self.get_priority(resource_type, resource_id)

      priority = nil
      
      if CfnManage.find_tags?
        
        $log.info("Looking for prority set by tags, will return default if tag is not found")
    
        case resource_type
        when 'AWS::AutoScaling::AutoScalingGroup'
          tags = CfnManage::TagReader.asg(resource_id)
          priority = CfnManage::TagReader.filter_by_key(tags,'cfn_manage:priority')
        end

      end
      
      if priority.nil?
        priority = @defaults[resource_type]      
      end
      
      $log.debug("type: #{resource_type}, id: #{resource_id}, priority: #{priority}")
      
      return priority
    end
  
  end
end
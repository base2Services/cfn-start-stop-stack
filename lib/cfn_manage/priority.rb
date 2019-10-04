require 'cfn_manage/aws_credentials'
require 'cfn_manage/asg_start_stop_handler'

module CfnManage
  class Priority
      
    def initialize()
      @priority_by_tags = (ENV.key? 'ORDER_BY_TAGS' and ENV['ORDER_BY_TAGS'] == '1')
      @credentials = CfnManage::AWSCredentials.get_session_credentials("cfn_manage_get_tags")
      @default_priorities = {
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
    end
  
    def get_priority(resource_type, resource_id)

      priority = nil
      
      if @priority_by_tags
    
        case resource_type
        when 'AWS::AutoScaling::AutoScalingGroup'
          tags = get_asg_tags(resource_id)
          priority = get_priority_tag(tags)
        end

      end
      
      if priority.nil?
        return @default_priorities[resource_id]      
      end
      
      return priority
    end
    
    def get_priority_tag(tags)
      tags.select {|tag| tag.key == 'cfn_manage:priority'}.collect {|tag| tag.value}.first
    end
    
    def get_asg_tags()
      client = Aws::AutoScaling::Client.new(credentials: @credentials, retry_limit: 20)
      resp = client.describe_tags({
        filters: [
          {
            name: "auto-scaling-group", 
            values: [@asg_name]
          }
        ]
      })
      return resp.tags
    end
  
  end
end
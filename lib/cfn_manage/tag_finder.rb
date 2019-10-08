require 'cfn_manage/aws_credentials'

require 'aws-sdk-autoscaling'

module CfnManage
  class TagFinder
    
    attr_accessor :priority, :wait_state
    
    def initialize(resource_id)
      @resource_id = resource_id
      @tags = []
    end
    
    def get_tags(resource_type)
      case resource_type
      when 'AWS::AutoScaling::AutoScalingGroup'
        asg()
      end
    end
    
    def priority()
      filter_by_key('cfn_manage:prority')
    end
    
    def wait_state()
      filter_by_key('cfn_manage:wait_state')
    end
      
    def filter_by_key(key)
      @tags.select {|tag| tag.key == key}.collect {|tag| tag.value}.first
    end
    
    def asg()
      credentials = CfnManage::AWSCredentials.get_session_credentials("cfn_manage_get_tags")
      client = Aws::AutoScaling::Client.new(credentials: credentials, retry_limit: 20)
      resp = client.describe_tags({
        filters: [
          {
            name: "auto-scaling-group", 
            values: [@resource_id]
          }
        ]
      })
      @tags = resp.tags
    end
      

  end
end
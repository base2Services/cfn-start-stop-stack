require 'cfn_manage/aws_credentials'

require 'aws-sdk-autoscaling'

module CfnManage
  class TagFinder
    
    attr_reader :priority, :opts
    
    def initialize(resource_id)
      @resource_id = resource_id
      @tags = []
    end
    
    def get_tags(resource_type)
      case resource_type
      when 'AWS::AutoScaling::AutoScalingGroup'
        asg()
      when 'AWS::EC2::Instance'
        ec2()
      when 'AWS::ECS::Cluster'
        ecs_cluster()
      end
    end
    
    def priority()
      @tags.select {|tag| tag.key == 'cfn_manage:prority'}.collect {|tag| tag.value}.first
    end
    
    def options()
      # collect all the cfn_manage tags and pass the back as a hash 
      # so they can be passed into the resource handers
      options = @tags.select {|tag| tag.key.start_with?('cfn_manage:') }
      options.collect { |tag| { tag.key.split(':').last.to_sym => tag.value } }.reduce(Hash.new,:merge)
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

    def ec2()
      credentials = CfnManage::AWSCredentials.get_session_credentials("cfn_manage_get_tags")
      client = Aws::EC2::Client.new(credentials: credentials, retry_limit: 20)
      resp = client.describe_tags({
        filters: [
          {
            name: "resource-id", 
            values: [@resource_id]
          }
        ]
      })
      @tags = resp.tags
    end
      
    def ecs_cluster()
      credentials = CfnManage::AWSCredentials.get_session_credentials("cfn_manage_get_tags")
      client = Aws::ECS::Client.new(credentials: credentials, retry_limit: 20)
      resp = client.describe_clusters({
        clusters: [@resource_id],
        include: ["TAGS"]
      })
      cluster = resp.clusters.first
      @tags = cluster.tags
    end

  end
end
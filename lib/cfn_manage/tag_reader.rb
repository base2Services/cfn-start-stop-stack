require 'cfn_manage/aws_credentials'

module CfnManage
  class TagReader
    class << self
      
      def filter_by_key(tags,key)
        tags.select {|tag| tag.key == key}.collect {|tag| tag.value}.first
      end
      
      def asg(resource_id)
        credentials = CfnManage::AWSCredentials.get_session_credentials("cfn_manage_get_tags")
        client = Aws::AutoScaling::Client.new(credentials: credentials, retry_limit: 20)
        resp = client.describe_tags({
          filters: [
            {
              name: "auto-scaling-group", 
              values: [resource_id]
            }
          ]
        })
        return resp.tags
      end
      
    end
  end
end
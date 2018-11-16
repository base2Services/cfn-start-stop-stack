module CfnManage

  module CloudFormation

    class Common

      def self.visit_stack(cf_client, stack_name, handler, visit_substacks)
        stack_resources = cf_client.describe_stack_resources(stack_name: stack_name)
        stack = cf_client.describe_stacks(stack_name: stack_name)

        # call traverse handler for parent stack
        handler.call(stack['stacks'][0].stack_name)

        # do not traverse unless instructed
        return unless visit_substacks

        stack_resources['stack_resources'].each do |resource|
          # test if resource us substack
          unless (resource['physical_resource_id'] =~ /arn:aws:cloudformation:(.*):stack\/(.*)/).nil?
            # call recursively
            stack_name = resource['physical_resource_id'].split('/')[1]
            self.visit_stack(cf_client, stack_name, handler, visit_substacks)
          end
        end
      end
    end
  end
end

require '../lib/cf_common.rb'
require 'aws-sdk-cloudformation'

cf_client = Aws::CloudFormation::Client.new(region:'us-east-1')

print_stack_name = lambda do |stack|
  puts "Stack: #{stack['stack_id']}"
end

Base2::CloudFormation::Common.traverse_substacks(cf_client, ENV['stack_name'], print_stack_name)

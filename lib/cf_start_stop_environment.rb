require 'aws-sdk'
require 'cf_common'

module Base2
  module CloudFormation
    class EnvironmentRunStop
      @cf_client = nil
      @stack_name = nil

      @@supported_start_stop_resources = {
        "AWS::AutoScaling::AutoScalingGroup" => 'start_stop_asg'
        "AWS::RDS::DBInstance" => 'start_stop_instance'
      }

      def initialize(stack_name, period_from, creds = nil, region = nil)
        client_params = {}
        client_params['region'] = region unless region.nil?
        client_params['credentials'] = creds unless creds.nil?
        @cf_client = Aws::CloudFormation::Client.new(client_params)
        @stack_name = stack_name
        @ending_statest = @@default_ending_states
        @period_from = period_from
      end

      def stop_environment
        Common.visit_stack(@cf_client, @stack_name, method(:stop_assets),true)
      end

      def stop_assets(stack)
        resrouces = @cf_client.describe_stack_resources(stack_name:stack_name)
        stack_resources['stack_resources'].each do |resource|
          if @@supported_start_stop_resources.key?(resource['resource_type'])
            method_name = resource['resource_type']
            resource_id = resource['physical_resource_id']
            eval "self.#{method_name}('stop','#{resource_id}')"
          end
        end
      end

      def start_stop_asg(cmd, asg)
        case cmd
        when 'start'
          #TODO retrieve ASG size from s3
          #TODO set ASG size to X
          break
        when 'stop'
          #TODO store ASG size to s3
          #TODO set ASG size to 0
          break
      end

      def start_stop_rds(cmd, instance_id)
        case cmd
        when 'start'
          #TODO retrieve multi-az data from S3
          #TODO start RDS instance
          #TODO convert rds instance to mutli-az if required

          break
        when 'stop'
          #TODO store mutli-az data to S3
          #TODO check if mutli-az RDS. if so, convert to single-az
          #TODO stop rds instance
          break
      end


    end
  end
end

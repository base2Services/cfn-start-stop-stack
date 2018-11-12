require 'aws-sdk-ec2'
require 'aws-sdk-s3'
require 'aws-sdk-ec2'
require 'aws-sdk-cloudformation'
require 'aws-sdk-rds'
require 'aws-sdk-cloudwatch'
require 'aws-sdk-autoscaling'
require 'aws-sdk-ecs'

require 'cfn_manage/cf_common'
require 'cfn_manage/aws_credentials'
require 'json'
require 'yaml'
require 'cfn_manage/start_stop_handler_factory'

module CfnManage
  module CloudFormation
    class EnvironmentRunStop

      @cf_client = nil
      @stack_name = nil
      @s3_client = nil
      @s3_bucket = nil
      @credentials = nil
      @dry_run = false

      @@resource_start_priorities = {
          'AWS::RDS::DBInstance' => '100',
          'AWS::RDS::DBCluster' => '100',
          'AWS::AutoScaling::AutoScalingGroup' => '200',
          'AWS::EC2::Instance' => '200',
          'AWS::EC2::SpotFleet' => '200',
          'AWS::ECS::Cluster' => '250',
          'AWS::CloudWatch::Alarm' => '300'
      }

      def initialize()
        @environment_resources = []
        @s3_client = Aws::S3::Client.new(retry_limit: 20)
        @s3_bucket = ENV['SOURCE_BUCKET']
        @cf_client = Aws::CloudFormation::Client.new(retry_limit: 20)
        @credentials = CfnManage::AWSCredentials.get_session_credentials('start_stop_environment')
        if not @credentials.nil?
          @cf_client = Aws::CloudFormation::Client.new(credentials: @credentials, retry_limit: 20)
        end
        @dry_run = (ENV.key?('DRY_RUN') and ENV['DRY_RUN'] == '1')
        @skip_wait = (ENV.key?('SKIP_WAIT') and ENV['SKIP_WAIT'] == '1')
        @wait_async = (ENV.key?('WAIT_ASYNC') and ENV['WAIT_ASYNC'] == '1')
        @continue_on_error = (ENV.key? 'CFN_CONTINUE_ON_ERROR' and ENV['CFN_CONTINUE_ON_ERROR'] == '1')
      rescue NoMethodError => e
        puts "Got No Method Error on CloudFormation::initialize, this often means that you're missing a AWS_DEFAULT_REGION"
      rescue Aws::Sigv4::Errors::MissingCredentialsError => e
        puts "Got Missing Credentials Error on CloudFormation::initialize, this often means that AWS_PROFILE is unset, or no default credentials were provided."
      end


      def start_environment(stack_name)
        $log.info("Starting environment #{stack_name}")
        Common.visit_stack(@cf_client, stack_name, method(:collect_resources), true)
        do_start_assets
        configuration = { stack_running: true }
        save_item_configuration("environment_data/stack-#{stack_name}", configuration) unless @dry_run
        $log.info("Environment #{stack_name} started")
      end


      def stop_environment(stack_name)
        $log.info("Stopping environment #{stack_name}")
        Common.visit_stack(@cf_client, stack_name, method(:collect_resources), true)
        do_stop_assets
        configuration = { stack_running: false }
        save_item_configuration("environment_data/stack-#{stack_name}", configuration) unless @dry_run
        $log.info("Environment #{stack_name} stopped")
      end

      def start_resource(resource_id,resource_type)
        start_stop_handler = CfnManage::StartStopHandlerFactory.get_start_stop_handler(
            resource_type,
            resource_id,
            @skip_wait
        )
        @environment_resources << {
            id: resource_id,
            priority: @@resource_start_priorities[resource_type],
            handler: start_stop_handler,
            type: resource_type
        }
        do_start_assets
      end

      def stop_resource(resource_id,resource_type)
        start_stop_handler = CfnManage::StartStopHandlerFactory.get_start_stop_handler(
            resource_type,
            resource_id,
            @skip_wait
        )
        @environment_resources << {
            id: resource_id,
            priority: @@resource_start_priorities[resource_type],
            handler: start_stop_handler,
            type: resource_type
        }
        do_stop_assets
      end

      def do_stop_assets
        # sort start resource by priority
        @environment_resources = @environment_resources.sort_by { |k| k[:priority] }.reverse
        environment_resources_by_priority = @environment_resources.partition { |k| k[:priority] }

        environment_resources_by_priority.each do |priority|
          priority.each do |resource|
            begin
              $log.info("Stopping resource #{resource[:id]}")
              # just print out information if running a dry run, otherwise start assets
              if not @dry_run
                configuration = resource[:handler].stop()
                if configuration.class == Hash
                  s3_prefix = "environment_data/resource/#{resource[:id]}"
                  save_item_configuration(s3_prefix, configuration)
                end
              else
                $log.info("Dry run enabled, skipping stop start\nFollowing resource would be stopped: #{resource[:id]}")
                $log.debug("Resource type: #{resource[:type]}\n\n")
              end
            rescue => e
              $log.error("An exception occurred during stop operation against resource #{resource[:id]}")
              $log.error("#{e.to_s}")
              $log.error(e.backtrace.join("\n\t"))
              if not @continue_on_error
                raise e
              end
            end
          end

          if not @dry_run and @wait_async
            priority.each do |resource|
              begin
                resource[:handler].wait('stopped')
              rescue => e
                $log.error("An exception occurred during wait operation against resource #{resource[:id]}")
                $log.error("#{e.to_s}")
                $log.error(e.backtrace.join("\n\t"))
                if not @continue_on_error
                  raise e
                end
              end
            end
          end

        end
      end

      def do_start_assets
        # sort start resource by priority
        @environment_resources = @environment_resources.sort_by { |k| k[:priority] }
        environment_resources_by_priority = @environment_resources.partition { |k| k[:priority] }

        environment_resources_by_priority.each do |priority|
          priority.each do |resource|
            begin
              $log.info("Starting resource #{resource[:id]}")
              # just print out information if running a dry run, otherwise start assets
              if not @dry_run
                # read configuration
                s3_prefix = "environment_data/resource/#{resource[:id]}"
                configuration = get_object_configuration(s3_prefix)

                # start
                resource[:handler].start(configuration)
              else
                $log.info("Dry run enabled, skipping actual start\nFollowing resource would be started: #{resource[:id]}")
                $log.debug("Resource type: #{resource[:type]}\n\n")
              end
            rescue => e
                $log.error("An exception occurred during start operation against resource #{resource[:id]}")
                $log.error("#{e.to_s}")
                $log.error(e.backtrace.join("\n\t"))
                if not @continue_on_error
                  raise e
                end
            end
          end

          if not @dry_run and @wait_async
            priority.each do |resource|
              begin
                resource[:handler].wait('available')
              rescue => e
                $log.error("An exception occurred during wait operation against resource #{resource[:id]}")
                $log.error("#{e.to_s}")
                $log.error(e.backtrace.join("\n\t"))
                if not @continue_on_error
                  raise e
                end
              end
            end

          end

        end
      end

      def collect_resources(stack_name)
        resrouces = @cf_client.describe_stack_resources(stack_name: stack_name)
        resrouces['stack_resources'].each do |resource|
          start_stop_handler = nil
          begin
            start_stop_handler = CfnManage::StartStopHandlerFactory.get_start_stop_handler(
                resource['resource_type'],
                resource['physical_resource_id'],
                @skip_wait
            )
          rescue Exception => e
            $log.error("Error creating start-stop handler for resource of type #{resource['resource_type']}" +
                "and with id #{resource['physical_resource_id']}:#{e}")
          end
          if not start_stop_handler.nil?
            resource_id = resource['physical_resource_id']
            @environment_resources << {
                id: resource_id,
                priority: @@resource_start_priorities[resource['resource_type']],
                handler: start_stop_handler,
                type: resource['resource_type']
            }
          end
        end
      end

      def get_object_configuration(s3_prefix)
        configuration = nil
        begin
          key = "#{s3_prefix}/latest/config.json"
          $log.info("Reading object configuration from s3://#{@s3_bucket}/#{key}")

          # fetch and deserialize and s3 object
          configuration = JSON.parse(@s3_client.get_object(bucket: @s3_bucket, key: key).body.read)

          $log.info("Configuration:#{configuration}")
        rescue Aws::S3::Errors::NoSuchKey
          $log.warn("Could not find configuration at s3://#{@s3_bucket}/#{key}")
        end
        configuration
      end

      def save_item_configuration(s3_prefix, configuration)
        # save latest configuration, and one time-based versioned
        s3_keys = [
            "#{s3_prefix}/latest/config.json",
            "#{s3_prefix}/#{Time.now.getutc.to_i}/config.json"
        ]
        s3_keys.each do |key|
          $log.info("Saving configuration to #{@s3_bucket}/#{key}\n#{configuration}")
          $log.info(configuration.to_yaml)
          @s3_client.put_object({
              bucket: @s3_bucket,
              key: key,
              body: JSON.pretty_generate(configuration)
          })
        end
      end

      private :do_stop_assets, :do_start_assets, :collect_resources, :get_object_configuration, :save_item_configuration

    end
  end
end

require 'aws-sdk'
require_relative '../lib/cf_common'
require_relative '../lib/aws_credentials'
require 'json'
require 'yaml'

module Base2
  module CloudFormation
    class EnvironmentRunStop

      @cf_client = nil
      @stack_name = nil
      @s3_client = nil
      @s3_bucket = nil
      @credentials = nil
      @dry_run = false
      @@supported_start_stop_resources = {
          'AWS::AutoScaling::AutoScalingGroup' => 'start_stop_asg',
          'AWS::RDS::DBInstance' => 'start_stop_rds'
      }

      @@resource_start_priorities = {
          'AWS::RDS::DBInstance' => '100',
          'AWS::AutoScaling::AutoScalingGroup' => '200'
      }

      @environment_resources = nil

      def initialize()
        @environment_resources = []
        @s3_client = Aws::S3::Client.new()
        @s3_bucket = ENV['SOURCE_BUCKET']
        @cf_client = Aws::CloudFormation::Client.new()
        @credentials = Base2::AWSCredentials.get_assume_role_credentials('start_stop_environment')
        if not @credentials.nil?
          @cf_client =  Aws::CloudFormation::Client.new(credentials: @credentials)
        end
        @dry_run = ENV.key?('DRY_RUN') and ENV['DRY_RUN'] == '1'
      end


      def start_environment(stack_name)
        $log.info("Starting environment #{stack_name}")
        Common.visit_stack(@cf_client, stack_name, method(:collect_resources), true)
        do_start_assets
        configuration = {stack_running: true}
        save_item_configuration("environment-data/stack-data/#{stack_name}", configuration) unless @dry_run
        $log.info("Environment #{stack_name} started")
      end


      def stop_environment(stack_name)
        $log.info("Stopping environment #{stack_name}")
        Common.visit_stack(@cf_client, stack_name, method(:collect_resources), true)
        do_stop_assets
        configuration = {stack_running: false}
        save_item_configuration("environment-data/stack-data/#{stack_name}", configuration) unless @dry_run
        $log.info("Environment #{stack_name} stopped")
      end


      def do_stop_assets
        # sort start resource by priority
        @environment_resources = @environment_resources.sort_by { |k| k[:priority]}.reverse

        @environment_resources.each do |resource|
          $log.info("Stopping resource #{resource[:id]}")
          # just print out information if running a dry run, otherwise start assets
          if not @dry_run
            eval "self.#{resource[:method]}('stop','#{resource[:id]}')"
          else
            $log.info("Dry run enabled, skipping stop start\nFollowing resource would be stopped: #{resource[:id]}")
            $log.debug("Resource type: #{resource[:type]}\n\n")
          end
        end
      end


      def do_start_assets
        # sort start resource by priority
        @environment_resources = @environment_resources.sort_by { |k| k[:priority]}

        @environment_resources.each do |resource|
          $log.info("Starting resource #{resource[:id]}")
          # just print out information if running a dry run, otherwise start assets
          if not @dry_run
            eval "self.#{resource[:method]}('start','#{resource[:id]}')"
          else
            $log.info("Dry run enabled, skipping actual start\nFollowing resource would be started: #{resource[:id]}")
            $log.debug("Resource type: #{resource[:type]}\n\n")
          end
        end
      end

      def collect_resources(stack_name)
        resrouces = @cf_client.describe_stack_resources(stack_name: stack_name)
        resrouces['stack_resources'].each do |resource|
          if @@supported_start_stop_resources.key?(resource['resource_type'])
            method_name = @@supported_start_stop_resources[resource['resource_type']]
            resource_id = resource['physical_resource_id']

            @environment_resources << {
                id: resource_id,
                priority: @@resource_start_priorities[resource['resource_type']],
                method: method_name,
                type: resource['resource_type']
            }
          end
        end
      end

      def start_stop_asg(cmd, asg_name)

        # read asg data
        credentials = Base2::AWSCredentials.get_assume_role_credentials("stopasg_#{asg_name}")
        asg_client = Aws::AutoScaling::Client.new()
        if credentials != nil
          asg_client = Aws::AutoScaling::Client.new(credentials: credentials)
        end

        asg_details = asg_client.describe_auto_scaling_groups(
            auto_scaling_group_names: [asg_name]
        )
        if asg_details.auto_scaling_groups.size() == 0
          raise "Couldn't find ASG #{asg_name}"
        end
        asg = asg_details.auto_scaling_groups[0]
        s3_prefix = "environment-data/asg-data/#{asg_name}"
        case cmd
          when 'start'

            # retrieve asg params from s3
            configuration = self.get_object_configuration(s3_prefix)

            $log.info("Starting ASG #{asg_name} with following configuration\n#{configuration}")

            # restore asg sizes
            asg_client.update_auto_scaling_group({
                auto_scaling_group_name: asg_name,
                min_size: configuration['min_size'],
                max_size: configuration['max_size'],
                desired_capacity: configuration['desired_capacity']
            })

          when 'stop'
            # store asg configuration to S3
            configuration = {
                desired_capacity: asg.desired_capacity,
                min_size: asg.min_size,
                max_size: asg.max_size
            }
            self.save_item_configuration(s3_prefix, configuration)

            $log.info("Setting desired capacity to 0/0/0 for ASG #{asg_name}")
            # set asg confugration to 0/0/0
            asg_client.update_auto_scaling_group({
                auto_scaling_group_name: asg_name,
                min_size: 0,
                max_size: 0,
                desired_capacity: 0
            })

          # TODO wait for operation to complete (optionally)
        end


      end

      def start_stop_rds(cmd, instance_id)
        credentials = Base2::AWSCredentials.get_assume_role_credentials("startstoprds_#{instance_id}")
        rds_client = Aws::RDS::Client.new()
        if credentials != nil
          rds_client = Aws::RDS::Client.new(credentials: credentials)
        end
        rds = Aws::RDS::Resource.new(client: rds_client)
        rds_instance = rds.db_instance(instance_id)
        s3_prefix = "environment-data/rds-data/#{instance_id}"
        case cmd
          when 'start'
            #retrieve multi-az data from S3
            configuration = get_object_configuration(s3_prefix)

            # start rds instance
            if rds_instance.db_instance_status == 'stopped'
              $log.info("Starting db instance #{instance_id}")
              rds_client.start_db_instance({ db_instance_identifier: instance_id })

              # wait instance to become available
              $log.info("Waiting db instance to become available #{instance_id}")
              wait_rds_instance_states(rds_instance, %w(starting available))
            else
              wait_rds_instance_states(rds_instance, %w(available))
            end


            # convert rds instance to mutli-az if required
            if configuration['is_multi_az']
              $log.info("Converting to Multi-AZ instance after start (instance #{instance_id})")
              set_rds_instance_multi_az(rds_instance, true)
            end

          when 'stop'
            # store mutli-az data to S3
            configuration = {
                is_multi_az: rds_instance.multi_az
            }
            save_item_configuration(s3_prefix, configuration)

            #check if mutli-az RDS. if so, convert to single-az
            if rds_instance.multi_az
              $log.info("Converting to Non-Multi-AZ instance before stop (instance #{instance_id}")
              set_rds_instance_multi_az(rds_instance, false)
            end

            # stop rds instance and wait for it to be fully stopped
            $log.info("Stopping instance #{instance_id}")
            rds_client.stop_db_instance({ db_instance_identifier: instance_id })
            $log.info("Waiting db instance to be stopped #{instance_id}")
            wait_rds_instance_states(rds_instance, %w(stopping stopped))
        end
      end

      def set_rds_instance_multi_az(rds_instance, multi_az)
        if rds_instance.multi_az == multi_az
          $log.info("Rds instance #{rds_instance.db_instance_identifier} already multi-az=#{multi_az}")
          return
        end
        rds_instance.modify({ multi_az: multi_az, apply_immediately: true })
        # allow half an hour for instance to be converted
        wait_states = %w(modifying available)
        wait_rds_instance_states(rds_instance, wait_states)
      end

      def wait_rds_instance_states(rds_instance, wait_states)
        wait_states.each do |state|
          # reached state must be steady, at least a minute. Modifying an instance to/from MultiAZ can't be shorter
          # than 40 seconds, hence steady count is 4
          state_count = 0
          steady_count = 4
          rds_instance.wait_until(max_attempts: 60*6, delay: 10) do |instance|
            $log.info("Instance #{instance.db_instance_identifier} state: #{instance.db_instance_status}, waiting for #{state}")
            if instance.db_instance_status == "#{state}"
              state_count = state_count + 1
              $log.info("#{state_count}/#{steady_count}")
            else
              state_count = 0
            end
            state_count == steady_count
          end
        end
      end

      def get_object_configuration(s3_prefix)
        key = "#{s3_prefix}/latest/config.json"
        $log.info("Reading object configuration from s3://#{@s3_bucket}/#{key}")

        # fetch and deserialize and s3 object
        configuration = JSON.parse(@s3_client.get_object(bucket: @s3_bucket, key: key).body.read)

        $log.info("Configuration:#{configuration}")
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
    end
  end
end

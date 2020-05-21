require 'aws-sdk-rds'
require 'cfn_manage/aws_credentials'

module CfnManage
  module StartStopHandler
    class Rds

      def initialize(instance_id, options = {})
        @instance_id = instance_id
        @excluded_engines = %w(aurora aurora-mysql aurora-postgresql) # RDS list of exluded engines that don't support RDS stop start
        credentials = CfnManage::AWSCredentials.get_session_credentials("startstoprds_#{instance_id}")
        @rds_client = Aws::RDS::Client.new(retry_limit: 20)
        if credentials != nil
          @rds_client = Aws::RDS::Client.new(credentials: credentials, retry_limit: 20)
        end
        rds = Aws::RDS::Resource.new(client: @rds_client)
        @rds_instance = rds.db_instance(instance_id)

      end

      def start(configuration)
        if @excluded_engines.include? @rds_instance.engine
           $log.info("RDS Instance #{@instance_id} engine is #{@rds_instance.engine} and cannot be started by instance.")
           return
        end

        if @rds_instance.db_instance_status == 'available'
          $log.info("RDS Instance #{@instance_id} is already in available state")
        end

        # start rds instance
        if @rds_instance.db_instance_status == 'stopped'
          $log.info("Starting db instance #{@instance_id}")
          @rds_client.start_db_instance({ db_instance_identifier: @instance_id })

          # wait instance to become available
          unless CfnManage.skip_wait?
            $log.info("Waiting db instance to become available #{@instance_id}")
            wait('available')
          end
        else
          wait('available') unless CfnManage.skip_wait?
        end

        # convert rds instance to mutli-az if required
        if configuration['is_multi_az']
          $log.info("Converting to Multi-AZ instance after start (instance #{@instance_id})")
          set_rds_instance_multi_az( true)
        end unless configuration.nil?
      end

      def stop

        configuration = {
            is_multi_az: @rds_instance.multi_az
        }
        # RDS list of exluded engines that don't support RDS stop start
        if @excluded_engines.include? @rds_instance.engine
           $log.info("RDS Instance #{@instance_id} engine is #{@rds_instance.engine} and cannot be stoped by instance.")
           return configuration
        end

        # check if available
        if @rds_instance.db_instance_status != 'available'
          $log.warn("RDS Instance #{@instance_id} not in available state, and thus can not be stopped")
          $log.warn("RDS Instance #{@instance_id} state: #{@rds_instance.db_instance_status}")
          return configuration
        end

        # check if already stopped
        if @rds_instance.db_instance_status == 'stopped'
          $log.info("RDS Instance #{@instance_id} is already stopped")
          return configuration
        end

        #check if mutli-az RDS. if so, convert to single-az
        if @rds_instance.multi_az
          $log.info("Converting to Non-Multi-AZ instance before stop (instance #{@instance_id}")
          set_rds_instance_multi_az(false)
        end

        # stop rds instance and wait for it to be fully stopped
        $log.info("Stopping instance #{@instance_id}")
        begin
          @rds_client.stop_db_instance({ db_instance_identifier: @instance_id })
        rescue Aws::RDS::Errors::InvalidDBInstanceState => e
          if e.message == "Cannot stop or start a Read-Replica instance"
            $log.warn("Skipping due to error: #{e.message}") 
            return
          else
            raise e
          end
        end
        unless CfnManage.skip_wait?
          $log.info("Waiting db instance to be stopped #{@instance_id}")
          wait('stopped')
        end
        return configuration
      end

      def set_rds_instance_multi_az(multi_az)
        if @rds_instance.multi_az == multi_az
          $log.info("Rds instance #{@rds_instance.db_instance_identifier} already multi-az=#{multi_az}")
          return
        end
        @rds_instance.modify({ multi_az: multi_az, apply_immediately: true })
        # allow half an hour for instance to be converted
        wait('available')
      end

      def wait(completed_state)
        # reached state must be steady, at least a minute. Modifying an instance to/from MultiAZ can't be shorter
        # than 40 seconds, hence steady count is 4
        state_count = 0
        steady_count = 4
        attempts = 0
        rds = Aws::RDS::Resource.new(client: @rds_client)
        until attempts == (max_attempts = 60*6) do
          instance = rds.db_instance(@instance_id)
          $log.info("Instance #{instance.db_instance_identifier} state: #{instance.db_instance_status}, waiting for #{completed_state}")

          if instance.db_instance_status == "#{completed_state}"
            state_count = state_count + 1
            $log.info("#{state_count}/#{steady_count}")
          else
            state_count = 0
          end
          break if state_count == steady_count
          attempts = attempts + 1
          sleep(15)
        end

        if attempts == max_attempts
          $log.error("RDS Database Instance #{@instance_id} did not enter #{state} state, however continuing operations...")
        end
      end

      private :set_rds_instance_multi_az

    end
  end
end

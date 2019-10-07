require 'aws-sdk-docdb'
require 'cfn_manage/aws_credentials'

module CfnManage
  module StartStopHandler
    class DocumentDb

      def initialize(cluster_id, skip_wait)
        @cluster_id = cluster_id
        credentials = CfnManage::AWSCredentials.get_session_credentials("startstopcluster_#{cluster_id}")
        @docdb_client = Aws::DocDB::Client.new(retry_limit: 20)
        if credentials != nil
          @docdb_client = Aws::DocDB::Client.new(credentials: credentials, retry_limit: 20)
        end
        cluster = @docdb_client.describe_db_clusters({ db_cluster_identifier: @cluster_id })
        @docdb_cluster = cluster.db_clusters.first
      end

      def start(configuration)
        if @docdb_cluster.status == 'available'
          $log.info("DocDB Cluster #{@cluster_id} is already in available state")
          return
        end

        # start docdb cluster
        if @docdb_cluster.status == 'stopped'
          $log.info("Starting DocDB cluster #{@cluster_id}")
          @docdb_client.start_db_cluster({ db_cluster_identifier: @cluster_id })
          unless CfnManage.skip_wait?
            # wait cluster to become available
            $log.info("Waiting DocDB cluster to become available #{@cluster_id}")
            wait('available')
          end
        else
          $log.info("DocDB Cluster #{@cluster_id} is not in a stopped state. State: #{@docdb_cluster.status}")
        end
      end

      def stop
        if @docdb_cluster.status == 'stopped'
          $log.info("DocDB Cluster #{@cluster_id} is already stopped")
          return {}
        end

        if @docdb_cluster.status != 'available'
          $log.info("DocDB Cluster #{@cluster_id} is not in a available state. State: #{@docdb_cluster.status}")
          return {}
        end
        # stop docdb cluster and wait for it to be fully stopped
        $log.info("Stopping DocDB cluster #{@cluster_id}")
        @docdb_client.stop_db_cluster({ db_cluster_identifier: @cluster_id })
        unless CfnManage.skip_wait?
          $log.info("Waiting DocDB cluster to be stopped #{@cluster_id}")
          wait('stopped')
        end
        return {}
      end

      def wait(completed_state)
        # reached state must be steady, at least a minute.
        state_count = 0
        steady_count = 4
        attempts = 0

        until attempts == (max_attempts = 60*6) do
          # Declare client and cluster variable a second time inside the loop so it re-evaluates each time.
          docdb = @docdb_client.describe_db_clusters({ db_cluster_identifier: @cluster_id })
          cluster = docdb.db_clusters.first
          $log.info("DocDB Cluster #{cluster.db_cluster_identifier} state: #{cluster.status}, waiting for #{completed_state}")

          if cluster.status == "#{completed_state}"
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
          $log.error("DocDB Cluster #{@cluster_id} did not enter #{completed_state} state, however continuing operations...")
        end
      end

    end
  end
end

require_relative '../lib/aws_credentials'

module Base2

  class AuroraClusterStartStopHandler

    def initialize(cluster_id)
      @cluster_id = cluster_id

      credentials = Base2::AWSCredentials.get_session_credentials("startstopcluster_#{cluster_id}")
      @rds_client = Aws::RDS::Client.new(retry_limit: 20)
      if credentials != nil
        @rds_client = Aws::RDS::Client.new(credentials: credentials, retry_limit: 20)
      end
      rds = Aws::RDS::Resource.new(client: @rds_client)
      @rds_cluster = rds.db_cluster(cluster_id)

    end

    def start(configuration)
      if @rds_cluster.status == 'available'
        $log.info("Aurora Cluster #{@cluster_id} is already in available state")
      end

      # start rds clsuter
      if @rds_cluster.status == 'stopped'
        $log.info("Starting Aurora cluster #{@cluster_id}")
        @rds_client.start_db_cluster({ db_cluster_identifier: @cluster_id })

        # wait cluster to become available
        $log.info("Waiting Aurora cluster to become available #{@cluster_id}")
        wait_rds_cluster_states( %w(starting available))
      else
        wait_rds_cluster_states( %w(available))
      end
    end

    def stop
      if @rds_cluster.status != 'available'
        $log.info("Aurora Cluster #{@cluster_id} is not in a available state. State: #{@rds_cluster.status}")
      end

      # stop rds cluster and wait for it to be fully stopped
      $log.info("Stopping aurora cluster #{@cluster_id}")
      @rds_client.stop_db_cluster({ db_cluster_identifier: @cluster_id })
      $log.info("Waiting aurora cluster to be stopped #{@cluster_id}")
      wait_rds_cluster_states(%w(stopping stopped))

      return {}
    end

    def wait_rds_cluster_states()
      wait_states.each do |state|
        # reached state must be steady, at least a minute.
        state_count = 0
        steady_count = 4
        attempts = 0
        rds = Aws::RDS::Resource.new(client: @rds_client)
        until attempts == (max_attempts = 60*6) do
          $log.info("Aurora Cluster #{@rds_cluster.db_cluster_identifier} state: #{@rds_cluster.status}, waiting for #{state}")

          if @rds_cluster.status == "#{state}"
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
          $log.error("RDS Aurora Cluster #{@cluster_id} did not enter #{state} state, however continuing operations...")
        end
      end
    end

  end

end

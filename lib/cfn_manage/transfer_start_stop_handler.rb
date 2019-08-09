require 'cfn_manage/aws_credentials'
require 'aws-sdk-transfer'

module CfnManage

  class TransferStartStopHandler

    def initialize(server_id, skip_wait)
      sftpId = server_id.split("/")
      @server_id = sftpId.last
      @skip_wait = skip_wait
      credentials = CfnManage::AWSCredentials.get_session_credentials("startstoptransfer_#{@server_id}")
      @client = Aws::Transfer::Client.new(retry_limit: 20)
      if credentials != nil
        @client = Aws::Transfer::Client.new(credentials: credentials, retry_limit: 20)
      end
    end

    def start(configuration)

      state = get_state()

      if state != "OFFLINE"
        $log.warn("SFTP Server #{@server_id} is in a state of #{state} and can not be started.")
        return
      end

      $log.info("Starting SFTP Server #{@server_id}")
      @client.start_server({
        server_id: @server_id,
      })
      unless @skip_wait
        $log.info("Waiting for SFTP to start #{@cluster_id}")
        wait('ONLINE')
      end

      return configuration
    end

    def stop()

      state = get_state()

      if state != "ONLINE"
        $log.warn("SFTP Server #{@server_id} is in a state of #{state} and can not be stopped.")
        return {}
      end

      @client.stop_server({
        server_id: @server_id,
      })
      unless @skip_wait
        $log.info("Waiting for SFTP to stop #{@cluster_id}")
        wait('OFFLINE')
      end
      return {}
    end

    def get_state()
      resp = @client.describe_server({
        server_id: @server_id,
      })
      return resp.server.state
    end

    def wait(completed_state)

      state_count = 0
      steady_count = 2
      attempts = 0
      until attempts == (max_attempts = 60*6) do
        state = get_state()
        $log.info("SFTP Server #{@server_id} state: #{state}, waiting for #{completed_state}")

        if state == "#{completed_state}"
          state_count = state_count + 1
          $log.info("#{state_count}/#{steady_count}")
        elsif ["START_FAILED", "STOP_FAILED"].include?(state)
          $log.error("SFTP Server #{@server_id} failed to reach state #{completed_state} with current state #{state}!")
          break
        else
          state_count = 0
        end
        break if state_count == steady_count
        attempts = attempts + 1
        sleep(15)
      end

      if attempts == max_attempts
        $log.error("SFTP Server #{@server_id} did not enter #{completed_state} state, however continuing operations...")
      end

    end

  end

end

require_relative '../lib/aws_credentials'

module Base2

  class AlarmStartStopHandler

    def initialize(alarm_name)
      @alarm_id = alarm_name
      credentials = Base2::AWSCredentials.get_session_credentials("startstopalarm_#{@asg_name}")
      @cwclient = Aws::CloudWatch::Client.new(retry_limit: 20)
      if credentials != nil
        @cwclient = Aws::CloudWatch::Client.new(credentials: credentials, retry_limit: 20)
      end

      @cwresource = Aws::CloudWatch::Resource.new(client: @cwclient)
      @alarm = @cwresource.alarm(alarm_name)
    end

    def start(configuration)
      if @alarm.actions_enabled
        $log.info("Alarm #{@alarm.alarm_arn} actions already enabled")
        return
      end
      $log.info("Enabling alarm #{@alarm.alarm_arn}")
      @alarm.enable_actions({})
    end

    def stop
      if not @alarm.actions_enabled
        $log.info("Alarm #{@alarm.alarm_arn} actions already disabled")
        return {}
      end
      $log.info("Disabling actions on alarm #{@alarm.alarm_arn}")
      @alarm.disable_actions({})
      return {}
    end

    def wait(wait_states=[])
      $log.debug("Not waiting for alarm #{@alarm_id}")
    end

  end

end

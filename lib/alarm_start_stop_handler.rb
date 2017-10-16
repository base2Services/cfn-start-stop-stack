require_relative '../lib/aws_credentials'

module Base2

  class AlarmStartStopHandler

    def initialize(alarm_id)
      @alarm_id = alarm_id
      $log.info("Start stop handler for alarm #{alarm_id}")
    end

    def start(configuration)
      $log.info("Alarm #{@alarm_id} enabled")
    end

    def start(configuration)
      $log.info("Alarm #{@alarm_id} disabled")
      return nil
    end


  end

end
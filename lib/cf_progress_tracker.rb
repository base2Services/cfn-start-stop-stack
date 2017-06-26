require 'aws-sdk'
require 'cf_common'

module Base2
  module CloudFormation
    class ProgressTracker
      @cf_client = nil
      @stack_name = nil
      @last_event_times = {}
      @period_from = nil

      @@default_ending_states = %w[
        CREATE_COMPLETE
        UPDATE_COMPLETE
        UPDATE_ROLLBACK_COMPLETE
        ROLLBACK_FAILED
        DELETE_FAILED
      ]

      @@default_display_state = %w[
          CREATE_COMPLETE
          UPDATE_COMPLETE
      ]

      @ending_states = nil

      def initialize(stack_name, period_from, creds = nil, region = nil)
        client_params = {}
        client_params['region'] = region unless region.nil?
        client_params['credentials'] = creds unless creds.nil?
        @cf_client = Aws::CloudFormation::Client.new(client_params)
        @stack_name = stack_name
        @ending_statest = @@default_ending_states
        @period_from = period_from
      end

       
      def track_single_stack(stack)
        stack_id = stack['stack_id']
        # Default to period_from if first run, take from last run otherwise
        event_from = last_event_times[stack_id] if @last_event_times.key?(stack_id)
        event_from = @period_from unless @last_event_times.key?(stack_id)
        

        stack_resources = @cf_client.describe_stack_events(stack_name: stack['stack_id'],)
        
        
      end

      def track_progress(_show_only_failures = false)
        Common.visit_stack(@cf_client, @stack_name, method(:track_single_stack),true)
      end
    end
  end
end

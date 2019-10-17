module CfnManage
  
  # set default options here
  @asg_wait_state = 'HealthyInASG'
  @ecs_wait_state = 'Skip'
  
  class << self
    
    # return the vale of our options
    attr_accessor :asg_wait_state, :ecs_wait_state
    
    # converts string based bolleans from aws tag values to bolleans
    def true?(obj)
      ["true","1"].include? obj.to_s.downcase
    end
    
    # find options set on resource tags
    def find_tags
      @find_tags = true
    end

    def find_tags?
      @find_tags
    end
    
    # don't stop or start resources
    def dry_run
      @dry_run = true
    end
    
    def dry_run?
      @dry_run
    end

    # dont wait for resources to become healthy
    def skip_wait
      @skip_wait = true
    end
    
    def skip_wait?
      @skip_wait
    end
    
    # wait for resources based upon priority groups
    def wait_async
      @wait_async = true
    end
    
    def wait_async?
      @wait_async
    end
    
    # dirty hack
    def ignore_missing_ecs_config
      @ignore_missing_ecs_config = true
    end
    
    def ignore_missing_ecs_config?
      @ignore_missing_ecs_config
    end
    
    # disable termination on asg when stopping EC2 instances in an asg
    def asg_suspend_termination
      @asg_suspend_termination = true
    end
    
    def asg_suspend_termination?
      @asg_suspend_termination
    end
    
    # continue if a resource fails to stop or start
    def continue_on_error
      @continue_on_error = true
    end
    
    def continue_on_error?
      @continue_on_error
    end
    
    # Wait for a container instances to join a ecs cluster
    def ecs_wait_container_instances
      @ecs_wait_container_instances = true
    end
    
    def ecs_wait_container_instances?
      @ecs_wait_container_instances
    end
    
  end
end

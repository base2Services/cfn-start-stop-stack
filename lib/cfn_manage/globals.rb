module CfnManage
  module_function
  
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
  
end

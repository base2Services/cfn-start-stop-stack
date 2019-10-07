module CfnManage
  module_function
  
  # find options set on resource tags
  def find_tags
    @find_tags = true
  end

  def find_tags?
    @find_tags
  end

  # dont wait for resources to become healthy
  def skip_wait
    @skip_wait = true
  end
  
  def skip_wait?
    @skip_wait
  end
  
end

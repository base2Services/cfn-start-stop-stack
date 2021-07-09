lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cfn_manage/version'

Gem::Specification.new do |spec|
  spec.name          = 'cfn_manage'
  spec.version       = CfnManage::VERSION
  spec.summary       = 'Manage AWS Cloud Formation stacks'
  spec.description   = 'Start and stop aws resources in a cloudformation stack'
  spec.authors       = ['Base2Services', 'Nikola Tosic', 'Angus Vine']
  spec.homepage      = 'https://github.com/base2Services/cfn-start-stop-stack/blob/master/README.md'
  spec.email         = 'itsupport@base2services.com'
  spec.license       = "MIT"
  
  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/base2services/aws-client-vpn"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  
  spec.required_ruby_version = '~> 2.5'

  spec.add_runtime_dependency 'aws-sdk-core', '>=3.39.0','<4'
  spec.add_runtime_dependency 'aws-sdk-s3', '~> 1', '<2'
  spec.add_runtime_dependency 'aws-sdk-ec2', '~> 1', '<2'
  spec.add_runtime_dependency 'aws-sdk-cloudformation', '~> 1', '<2'
  spec.add_runtime_dependency 'aws-sdk-rds', '>=1.31.0', '<2'
  spec.add_runtime_dependency 'aws-sdk-cloudwatch', '~> 1', '<2'
  spec.add_runtime_dependency 'aws-sdk-iam', '~> 1', '<2'
  spec.add_runtime_dependency 'aws-sdk-autoscaling', '~> 1', '<2'
  spec.add_runtime_dependency 'aws-sdk-ecs', '~> 1', '<2'
  spec.add_runtime_dependency 'aws-sdk-docdb', '>=1.9.0', '<2'
  spec.add_runtime_dependency 'aws-sdk-transfer', '~>1', '<2'
  spec.add_runtime_dependency 'aws-sdk-elasticloadbalancingv2', '~>1', '<2'

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 0.9"
  spec.add_development_dependency "rspec-core", "~> 3.8"
  spec.add_development_dependency "rspec-expectations", "~> 3.8"
  spec.add_development_dependency "rspec-mocks", "~> 3.8"
  spec.add_development_dependency 'simplecov', '~> 0.16'
end

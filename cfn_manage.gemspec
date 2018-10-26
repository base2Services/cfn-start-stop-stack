require 'rake'
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cfn_manage/version'

Gem::Specification.new do |spec|
  spec.name          = 'cfn_manage'
  spec.version       = CfnManage::VERSION
  spec.summary       = 'Manage AWS Cloud Formation stacks'
  spec.description   = ''
  spec.authors       = ['Base2Services', 'Nikola Tosic', 'Angus Vine']
  spec.email         = 'itsupport@base2services.com'
  spec.files         = FileList['lib/**/*.rb', 'bin/*']
  spec.require_paths = ["lib"]
  spec.homepage      = 'https://github.com/base2Services/cfn-start-stop-stack/blob/master/README.md'
  spec.license       = 'MIT'
  spec.executables << 'cfn_manage'

  spec.add_runtime_dependency 'aws-sdk-core', '~> 3','<4'
  spec.add_runtime_dependency 'aws-sdk-s3', '~> 1', '<2'
  spec.add_runtime_dependency 'aws-sdk-ec2', '~> 1', '<2'
  spec.add_runtime_dependency 'aws-sdk-cloudformation', '~> 1', '<2'
  spec.add_runtime_dependency 'aws-sdk-rds', '>=1.31.0', '<2'
  spec.add_runtime_dependency 'aws-sdk-cloudwatch', '~> 1', '<2'
  spec.add_runtime_dependency 'aws-sdk-iam', '~> 1', '<2'
  spec.add_runtime_dependency 'aws-sdk-autoscaling', '~> 1', '<2'
  spec.add_runtime_dependency 'aws-sdk-ecs', '~> 1', '<2'

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 0.9"
  spec.add_development_dependency "rspec-core", "~> 3.8"
  spec.add_development_dependency "rspec-expectations", "~> 3.8"
  spec.add_development_dependency "rspec-mocks", "~> 3.8"
  spec.add_development_dependency 'simplecov', '~> 0.16'
end

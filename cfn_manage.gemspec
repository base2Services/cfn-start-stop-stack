require 'rake'

Gem::Specification.new do |s|
  s.name        = 'cfn_manage'
  s.version     = '0.3.0'
  s.date        = '2018-04-26'
  s.summary     = 'Manage AWS Cloud Formation stacks'
  s.description = ''
  s.authors     = ['Base2Services', 'Nikola Tosic']
  s.email       = 'itsupport@base2services.com'
  s.files       = FileList["lib/*.rb","bin/*"]
  s.homepage    = 'https://github.com/base2Services/cfn-library/blob/master/README.md'
  s.license       = 'MIT'
  s.executables << 'cfn_manage'
  s.add_runtime_dependency 'aws-sdk-core', '~> 3','<4'
  s.add_runtime_dependency 'aws-sdk-s3', '~> 1', '<2'
  s.add_runtime_dependency 'aws-sdk-ec2', '~> 1', '<2'
  s.add_runtime_dependency 'aws-sdk-cloudformation', '~> 1', '<2'
  s.add_runtime_dependency 'aws-sdk-rds', '~> 1', '<2'
  s.add_runtime_dependency 'aws-sdk-cloudwatch', '~> 1', '<2'
  s.add_runtime_dependency 'aws-sdk-iam', '~> 1', '<2'
  s.add_runtime_dependency 'aws-sdk-autoscaling', '~> 1', '<2'
end
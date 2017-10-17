require 'rake'

Gem::Specification.new do |s|
  s.name        = 'cfn_manage'
  s.version     = '0.1.3'
  s.date        = '2017-09-26'
  s.summary     = 'Manage AWS Cloud Formation stacks'
  s.description = ''
  s.authors     = ['Base2Services', 'Nikola Tosic']
  s.email       = 'itsupport@base2services.com'
  s.files       = FileList["lib/*.rb","bin/*"]
  s.homepage    = 'https://github.com/base2Services/cfn-library/blob/master/README.md'
  s.license       = 'MIT'
  s.executables << 'cfn_manage'
  s.add_runtime_dependency 'aws-sdk','>=3','<4'
end
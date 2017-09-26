require 'rake'

Gem::Specification.new do |s|
  s.name        = 'cfn_manage'
  s.version     = '0.1.0'
  s.date        = '2017-09-26'
  s.summary     = 'Manage Cloud Formation stacks'
  s.description = ''
  s.authors     = ['Base2Services', 'Nikola Tosic']
  s.email       = 'info@base2services.com'
  s.files       = FileList["lib/*.rb","bin/*"]
  s.homepage    = 'http://rubygems.org/gems/cfn_manage'
  s.license       = 'MIT'
  s.executables << 'cfn_manage'
  s.add_runtime_dependency 'aws-sdk','>=3'
end
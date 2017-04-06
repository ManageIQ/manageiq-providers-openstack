$:.push File.expand_path("../lib", __FILE__)

require "manageiq/providers/openstack/version"

Gem::Specification.new do |s|
  s.name        = "manageiq-providers-openstack"
  s.version     = ManageIQ::Providers::Openstack::VERSION
  s.authors     = ["ManageIQ Developers"]
  s.homepage    = "https://github.com/ManageIQ/manageiq-providers-openstack"
  s.summary     = "Openstack Provider for ManageIQ"
  s.description = "Openstack Provider for ManageIQ"
  s.licenses    = ["Apache-2.0"]

  s.files = Dir["{app,config,lib}/**/*"]

  s.add_development_dependency "codeclimate-test-reporter", "~> 1.0.0"
  s.add_development_dependency "simplecov"
end

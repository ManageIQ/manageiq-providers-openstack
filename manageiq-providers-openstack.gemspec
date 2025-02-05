# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'manageiq/providers/openstack/version'

Gem::Specification.new do |spec|
  spec.name          = "manageiq-providers-openstack"
  spec.version       = ManageIQ::Providers::Openstack::VERSION
  spec.authors       = ["ManageIQ Authors"]

  spec.summary       = "ManageIQ plugin for the OpenStack provider."
  spec.description   = "ManageIQ plugin for the OpenStack provider."
  spec.homepage      = "https://github.com/ManageIQ/manageiq-providers-openstack"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport",        ">=6.0"
  spec.add_dependency "bunny",                "~> 2.1.0"
  spec.add_dependency "excon",                "~> 0.71"
  spec.add_dependency "fog-openstack",        "~> 1.1", ">= 1.1.4"
  spec.add_dependency "more_core_extensions", ">= 3.2", "< 5"
  spec.add_dependency "parallel",             "~> 1.12"

  spec.add_development_dependency "manageiq-style"
  spec.add_development_dependency "simplecov", ">= 0.21.2"
end

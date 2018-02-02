require "manageiq/providers/openstack/engine"
require "manageiq/providers/openstack/version"

module ManageIQ
  module Providers
    module Openstack
      autoload :Discovery, 'manageiq/providers/openstack/discovery'
    end
  end
end

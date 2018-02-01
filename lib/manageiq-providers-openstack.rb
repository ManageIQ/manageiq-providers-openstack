require "manageiq/providers/openstack/engine"
require "manageiq/providers/openstack/version"

module ManageIQ
  module Providers
    module Openstack
      autoload :InfraDiscovery, 'manageiq/providers/openstack/infra_discovery'
    end
  end
end

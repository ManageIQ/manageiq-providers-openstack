module ManageIQ
  module Providers
    module Openstack
      class Engine < ::Rails::Engine
        isolate_namespace ManageIQ::Providers::Openstack

        def self.plugin_name
          _('OpenStack Provider')
        end
      end
    end
  end
end

module ManageIQ
  module Providers
    module Openstack
      class Engine < ::Rails::Engine
        isolate_namespace ManageIQ::Providers::Openstack

        config.autoload_paths << root.join('lib').to_s

        def self.vmdb_plugin?
          true
        end

        def self.plugin_name
          _('OpenStack Provider')
        end
      end
    end
  end
end

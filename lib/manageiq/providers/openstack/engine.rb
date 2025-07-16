module ManageIQ
  module Providers
    module Openstack
      class Engine < ::Rails::Engine
        isolate_namespace ManageIQ::Providers::Openstack

        config.autoload_paths << root.join('lib')

        def self.vmdb_plugin?
          true
        end

        def self.plugin_name
          _('OpenStack Provider')
        end

        def self.init_loggers
          $fog_log ||= Vmdb::Loggers.create_logger("fog.log", Vmdb::Loggers::FogLogger)
        end

        def self.apply_logger_config(config)
          Vmdb::Loggers.apply_config_value(config, $fog_log, :level_fog)
        end
      end
    end
  end
end

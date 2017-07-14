class ManageIQ::Providers::Openstack::Builder
  class << self
    def build_inventory(ems, target)
      case target
      when ManageIQ::Providers::Openstack::CloudManager
        cloud_manager_inventory(ems, target)
      when ManageIQ::Providers::Openstack::NetworkManager
        inventory(
          ems,
          target,
          ManageIQ::Providers::Openstack::Inventory::Collector::NetworkManager,
          ManageIQ::Providers::Openstack::Inventory::Persister::NetworkManager,
          [ManageIQ::Providers::Openstack::Inventory::Parser::NetworkManager]
        )
      when ManagerRefresh::TargetCollection
        inventory(
          ems,
          target,
          ManageIQ::Providers::Openstack::Inventory::Collector::TargetCollection,
          ManageIQ::Providers::Openstack::Inventory::Persister::TargetCollection,
          [ManageIQ::Providers::Openstack::Inventory::Parser::CloudManager,
           ManageIQ::Providers::Openstack::Inventory::Parser::NetworkManager]
        )
      else
        # Fallback to ems refresh
        cloud_manager_inventory(ems, target)
      end
    end

    private

    def cloud_manager_inventory(ems, target)
      inventory(
        ems,
        target,
        ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager,
        ManageIQ::Providers::Openstack::Inventory::Persister::CloudManager,
        [ManageIQ::Providers::Openstack::Inventory::Parser::CloudManager]
      )
    end

    def inventory(manager, raw_target, collector_class, persister_class, parsers_classes)
      collector = collector_class.new(manager, raw_target)
      # TODO(lsmola) figure out a way to pass collector info, probably via target
      persister = persister_class.new(manager, raw_target, collector)

      ::ManageIQ::Providers::Openstack::Inventory.new(
        persister,
        collector,
        parsers_classes.map(&:new)
      )
    end
  end
end

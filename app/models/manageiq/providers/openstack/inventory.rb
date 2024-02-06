class ManageIQ::Providers::Openstack::Inventory < ManageIQ::Providers::Inventory
  # Default manager for building collector/parser/persister classes
  # when failed to get class name from refresh target automatically
  def self.default_manager_name
    "CloudManager"
  end

  def self.parser_classes_for(_ems, target)
    case target
    when InventoryRefresh::TargetCollection
      [ManageIQ::Providers::Openstack::Inventory::Parser::CloudManager,
       ManageIQ::Providers::Openstack::Inventory::Parser::NetworkManager,
       ManageIQ::Providers::Openstack::Inventory::Parser::StorageManager::CinderManager]
    else
      super
    end
  end
end

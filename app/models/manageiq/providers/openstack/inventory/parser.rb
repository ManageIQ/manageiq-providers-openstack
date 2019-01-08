class ManageIQ::Providers::Openstack::Inventory::Parser < ManageIQ::Providers::Inventory::Parser
  require_nested :CloudManager
  require_nested :InfraManager
  require_nested :NetworkManager
  require_nested :StorageManager
end

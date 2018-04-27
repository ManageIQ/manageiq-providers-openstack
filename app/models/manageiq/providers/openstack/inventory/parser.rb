class ManageIQ::Providers::Openstack::Inventory::Parser < ManagerRefresh::Inventory::Parser
  require_nested :CloudManager
  require_nested :NetworkManager
  require_nested :CinderManager
end

class ManageIQ::Providers::Openstack::StorageManager::CinderManager < ManageIQ::Providers::StorageManager::CinderManager
  require_nested :Refresher
  include ManageIQ::Providers::Openstack::ManagerMixin
end

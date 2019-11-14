class ManageIQ::Providers::Openstack::NetworkManager::RefreshWorker < ::MiqEmsRefreshWorker
  require_nested :Runner

  def self.settings_name
    :ems_refresh_worker_openstack_network
  end
end

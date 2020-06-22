class ManageIQ::Providers::Openstack::InfraManager::RefreshWorker < ::MiqEmsRefreshWorker
  require_nested :Runner

  def self.settings_name
    :ems_refresh_worker_openstack_infra
  end
end

class ManageIQ::Providers::Openstack::InfraManager::HostServiceGroup < ::HostServiceGroup
  def host_service_group_filesystems
    Filesystem.host_service_group_filesystems(id)
  end

  def running_system_services
    SystemService.host_service_group_running_systemd(id)
  end

  def failed_system_services
    SystemService.host_service_group_failed_systemd(id)
  end
end

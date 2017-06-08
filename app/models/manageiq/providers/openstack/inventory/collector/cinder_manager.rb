class ManageIQ::Providers::Openstack::Inventory::Collector::CinderManager < ManagerRefresh::Inventory::Collector
  def cinder_service
    @os_handle ||= manager.parent_manager.openstack_handle
    @cinder_service ||= manager.parent_manager.cinder_service
  end

  def volumes
    @volumes ||= cinder_service.handled_list(:volumes)
  end

  def snapshots
    @snapshots ||= cinder_service.handled_list(:list_snapshots_detailed, :__request_body_index => "snapshots")
  end

  def backups
    @backups ||= cinder_service.list_backups_detailed.body["backups"]
  end
end

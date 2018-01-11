class ManageIQ::Providers::Openstack::Inventory::Collector::StorageManager::CinderManager < ManageIQ::Providers::Openstack::Inventory::Collector
  include ManageIQ::Providers::Openstack::Inventory::Collector::HelperMethods

  def volumes
    return @volumes if @volumes.any?
    @volumes = cinder_service.handled_list(:volumes)
  end

  def snapshots
    return @snapshots if @snapshots.any?
    @snapshots = cinder_service.handled_list(:list_snapshots_detailed, :__request_body_index => "snapshots")
  end

  def backups
    return @backups if @backups.any?
    @backups = cinder_service.list_backups_detailed.body["backups"]
  end
end

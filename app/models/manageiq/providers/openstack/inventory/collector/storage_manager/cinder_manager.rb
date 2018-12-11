class ManageIQ::Providers::Openstack::Inventory::Collector::StorageManager::CinderManager < ManageIQ::Providers::Openstack::Inventory::Collector
  include ManageIQ::Providers::Openstack::Inventory::Collector::HelperMethods

  def cloud_volumes
    return [] unless volume_service
    return @cloud_volumes if @cloud_volumes.any?
    @cloud_volumes = volume_service.handled_list(:volumes, {}, cinder_admin?)
  end

  def cloud_volume_snapshots
    return [] unless volume_service
    return @cloud_volume_snapshots if @cloud_volume_snapshots.any?
    @cloud_volume_snapshots = volume_service.handled_list(:list_snapshots_detailed, {:__request_body_index => "snapshots"}, cinder_admin?)
  end

  def cloud_volume_backups
    return [] unless volume_service
    return @cloud_volume_backups if @cloud_volume_backups.any?
    @cloud_volume_backups = volume_service.handled_list(:list_backups_detailed, {:__request_body_index => "backups"}, cinder_admin?)
  end

  def cloud_volume_types
    return [] unless volume_service
    return @cloud_volume_types if @cloud_volume_types.any?
    @cloud_volume_types = volume_service.handled_list(:volume_types, {}, cinder_admin?)
  end
end

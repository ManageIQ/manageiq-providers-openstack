module ManageIQ::Providers::Openstack::Inventory::Persister::Definitions::StorageCollections
  extend ActiveSupport::Concern

  def initialize_storage_inventory_collections
    %i(cloud_volumes
       cloud_volume_snapshots
       cloud_volume_types
       ).each do |name|

      add_collection(cloud, name) do |builder|
        builder.add_properties(:model_class => "ManageIQ::Providers::Openstack::StorageManager::CinderManager::#{name.to_s.classify}".constantize)
        if targeted?
          builder.add_properties(:parent => manager.cinder_manager)
          builder.add_default_values(:ems_id => manager.cinder_manager.try(:id))
        else
          builder.add_default_values(:ems_id => manager.id)
        end
      end
    end
    add_cloud_volume_backups
  end

  def add_cloud_volume_backups(extra_properties = {})
    add_collection(cloud, :cloud_volume_backups, extra_properties) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::Openstack::StorageManager::CinderManager::CloudVolumeBackup)
      if targeted?
        builder.add_properties(:parent => manager.cinder_manager)
        builder.add_default_values(:ems_id => manager.cinder_manager.try(:id))
      else
        builder.add_default_values(:ems_id => manager.id)
      end
      # targeted refresh workaround-- always refresh the whole backup collection
      # regardless of whether this is a TargetCollection or not
      # because OpenStack doesn't give us UUIDs of changed volume_backups,
      # we just get an event that one of them changed
      if references(:cloud_volume_backups).present?
        builder.add_properties(:targeted => false)
      end
    end
  end
end

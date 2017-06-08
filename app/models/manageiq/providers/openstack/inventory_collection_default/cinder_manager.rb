class ManageIQ::Providers::Openstack::InventoryCollectionDefault::CinderManager < ManagerRefresh::InventoryCollectionDefault::StorageManager
  class << self
    def cloud_volume_backups(extra_attributes = {})
      attributes = {
        :model_class                 => ManageIQ::Providers::Openstack::CloudManager::CloudVolumeBackup,
        :association                 => :cloud_volume_backups,
        :inventory_object_attributes => [
          :type,
          :ems_ref,
          :status,
          :creation_time,
          :size,
          :object_count,
          :is_incremental,
          :has_dependent_backups,
          :name,
          :description,
          :cloud_volume,
          :availability_zone
        ]
      }

      attributes.merge!(extra_attributes)
    end

    def cloud_volume_snapshots(extra_attributes = {})
      attributes = {
        :model_class                 => ManageIQ::Providers::Openstack::CloudManager::CloudVolumeSnapshot,
        :inventory_object_attributes => [
          :type,
          :ems_ref,
          :status,
          :creation_time,
          :size,
          :name,
          :description,
          :cloud_volume,
          :cloud_tenant
        ]
      }
      super(attributes.merge!(extra_attributes))
    end

    def cloud_volumes(extra_attributes = {})
      attributes = {
        :model_class                 => ManageIQ::Providers::Openstack::CloudManager::CloudVolume,
        :inventory_object_attributes => [
          :type,
          :ems_ref,
          :status,
          :bootable,
          :volume_type,
          :creation_time,
          :size,
          :name,
          :description,
          :base_snapshot,
          :availability_zone,
          :cloud_tenant
        ]
      }
      super(attributes.merge!(extra_attributes))
    end
  end
end

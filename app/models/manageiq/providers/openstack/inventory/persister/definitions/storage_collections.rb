module ManageIQ::Providers::Openstack::Inventory::Persister::Definitions::StorageCollections
  extend ActiveSupport::Concern

  def initialize_storage_inventory_collections
    %i(cloud_volumes
       cloud_volume_snapshots
       cloud_volume_backups
       cloud_volume_types
       ).each do |name|

      add_collection(cloud, name) do |builder|
        if targeted?
          builder.add_properties(:parent => manager.cinder_manager)
          builder.add_default_values(:ems_id => manager.cinder_manager.try(:id))
        else
          builder.add_default_values(:ems_id => manager.id)
        end
      end
    end
  end
end

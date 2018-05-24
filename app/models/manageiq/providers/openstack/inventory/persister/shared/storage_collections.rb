module ManageIQ::Providers::Openstack::Inventory::Persister::Shared::StorageCollections
  extend ActiveSupport::Concern

  def initialize_storage_inventory_collections
    %i(cloud_volumes
       cloud_volume_snapshots
       cloud_volume_backups).each do |name|

      add_collection(cloud, name) do |builder|
        if targeted?
          builder.add_properties(:parent => manager.cinder_manager)
          builder.add_builder_params(:ext_management_system => manager.cinder_manager)
        else
          builder.add_builder_params(:ext_management_system => manager)
        end
      end
    end
  end
end

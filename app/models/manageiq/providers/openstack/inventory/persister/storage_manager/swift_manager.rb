class ManageIQ::Providers::Openstack::Inventory::Persister::StorageManager::SwiftManager < ManageIQ::Providers::Openstack::Inventory::Persister
  def initialize_inventory_collections
    add_storage_collection(:cloud_object_store_objects)
    add_storage_collection(:cloud_object_store_containers)
    add_cloud_collection(:cloud_tenants) do |builder|
      builder.add_properties(:strategy => :local_db_cache_all, :complete => false)
    end
  end

  private

  def storage_manager
    manager.kind_of?(EmsStorage) ? manager : manager.swift_manager
  end
end

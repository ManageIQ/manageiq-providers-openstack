class ManageIQ::Providers::Openstack::Inventory::Persister::StorageManager::SwiftManager < ManageIQ::Providers::Openstack::Inventory::Persister
  def initialize_inventory_collections
    add_collection(storage, :cloud_object_store_objects)
    add_collection(storage, :cloud_object_store_containers)

    add_collection(cloud, :cloud_tenants, :parent => manager.parent_manager) do |builder|
      builder.add_properties(:strategy => :local_db_cache_all, :complete => false)
    end
  end
end

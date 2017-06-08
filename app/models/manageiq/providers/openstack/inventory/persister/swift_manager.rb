class ManageIQ::Providers::Openstack::Inventory::Persister::SwiftManager < ManagerRefresh::Inventory::Persister
  def swift
    ManageIQ::Providers::Openstack::InventoryCollectionDefault::SwiftManager
  end

  def cloud
    ManageIQ::Providers::Openstack::InventoryCollectionDefault::CloudManager
  end

  def initialize_inventory_collections
    add_inventory_collections(swift,
                              %i(
                                cloud_object_store_containers
                                cloud_object_store_objects
                              ),
                              :builder_params => {:ext_management_system => manager})

    add_inventory_collections(cloud,
                              %i(
                                cloud_tenants
                              ),
                              :parent   => manager.parent_manager,
                              :strategy => :local_db_cache_all)
  end
end

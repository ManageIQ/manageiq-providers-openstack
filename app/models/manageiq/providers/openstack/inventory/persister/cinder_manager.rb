class ManageIQ::Providers::Openstack::Inventory::Persister::CinderManager < ManagerRefresh::Inventory::Persister
  def cinder
    ManageIQ::Providers::Openstack::InventoryCollectionDefault::CinderManager
  end

  def cloud
    ManageIQ::Providers::Openstack::InventoryCollectionDefault::CloudManager
  end

  def initialize_inventory_collections
    add_inventory_collections(cinder,
                              %i(
                                cloud_volumes
                                cloud_volume_snapshots
                                cloud_volume_backups
                              ),
                              :builder_params => {:ext_management_system => manager})

    add_inventory_collections(cloud,
                              %i(
                                availability_zones
                                hardwares
                                cloud_tenants
                              ),
                              :parent   => manager.parent_manager,
                              :strategy => :local_db_find_references)

    add_inventory_collections(cloud,
                              %i(
                                disks
                              ),
                              :parent   => manager.parent_manager,
                              :complete => false)
  end
end

class ManageIQ::Providers::Openstack::Inventory::Persister::TargetCollection < ManageIQ::Providers::Openstack::Inventory::Persister
  include ManageIQ::Providers::Openstack::Inventory::Persister::Definitions::CloudCollections
  include ManageIQ::Providers::Openstack::Inventory::Persister::Definitions::NetworkCollections
  include ManageIQ::Providers::Openstack::Inventory::Persister::Definitions::StorageCollections

  def targeted?
    true
  end

  def initialize_inventory_collections
    initialize_tag_mapper
    initialize_cloud_inventory_collections
    initialize_network_inventory_collections
    initialize_cinder_inventory_collections
  end
end

class ManageIQ::Providers::Openstack::Inventory::Persister::CloudManager < ManageIQ::Providers::Openstack::Inventory::Persister
  include ManageIQ::Providers::Openstack::Inventory::Persister::Definitions::CloudCollections

  def initialize_inventory_collections
    initialize_tag_mapper

    initialize_cloud_inventory_collections
  end
end

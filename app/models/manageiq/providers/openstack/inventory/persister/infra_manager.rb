class ManageIQ::Providers::Openstack::Inventory::Persister::InfraManager < ManageIQ::Providers::Openstack::Inventory::Persister
  include ManageIQ::Providers::Openstack::Inventory::Persister::Definitions::InfraCollections

  def initialize_inventory_collections
    initialize_infra_inventory_collections
  end
end

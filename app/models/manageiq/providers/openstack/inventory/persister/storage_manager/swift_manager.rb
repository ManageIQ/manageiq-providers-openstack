class ManageIQ::Providers::Openstack::Inventory::Persister::StorageManager::SwiftManager < ManageIQ::Providers::Openstack::Inventory::Persister
  include ManageIQ::Providers::Openstack::Inventory::Persister::Definitions::StorageCollections

  def initialize_inventory_collections
    initialize_swift_inventory_collections
  end
end

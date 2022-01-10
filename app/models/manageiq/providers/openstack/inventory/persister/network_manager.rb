class ManageIQ::Providers::Openstack::Inventory::Persister::NetworkManager < ManageIQ::Providers::Openstack::Inventory::Persister
  include ManageIQ::Providers::Openstack::Inventory::Persister::Definitions::CloudCollections
  include ManageIQ::Providers::Openstack::Inventory::Persister::Definitions::NetworkCollections

  def initialize_inventory_collections
    initialize_network_inventory_collections

    initialize_cloud_inventory_collections
  end

  protected

  def initialize_cloud_inventory_collections
    %i(vms
       orchestration_stacks
       orchestration_stacks_resources
       availability_zones
       cloud_tenants).each do |name|

      add_collection(cloud, name, shared_cloud_properties, {:without_sti => true})
    end

    add_orchestration_stacks(shared_cloud_properties)
  end

  private

  def shared_cloud_properties
    {:parent   => manager.parent_manager,
     :strategy => :local_db_cache_all}
  end
end

module ManageIQ::Providers::Openstack::Inventory::Persister::Shared::NetworkCollections
  extend ActiveSupport::Concern

  def network
    ::ManagerRefresh::InventoryCollection::Builder::NetworkManager
  end

  def initialize_network_inventory_collections
    %i(cloud_networks
       cloud_subnets
       floating_ips
       network_routers
       security_groups).each do |name|

      add_collection(network, name) do |builder|
        builder.add_builder_params(:ext_management_system => (targeted? ? manager.network_manager : manager))
      end
    end

    add_network_ports

    add_cloud_subnet_network_ports

    add_firewall_rules
  end

  # ------ IC provider specific definitions -------------------------

  def add_network_ports
    add_collection(network, :network_ports) do |builder|
      builder.add_properties(:delete_method => :disconnect_port)

      builder.add_builder_params(:ext_management_system => (targeted? ? manager.network_manager : manager))
s    end
  end

  def add_cloud_subnet_network_ports
    add_collection(network, :cloud_subnet_network_ports) do |builder|
      builder.add_properties(
        :parent_inventory_collections => %i(vms network_ports)
      )
    end
  end

  def add_firewall_rules
    add_collection(network, :firewall_rules) do |builder|
      builder.add_properties(
        :manager_ref => %i(ems_ref)
      )
    end
  end
end

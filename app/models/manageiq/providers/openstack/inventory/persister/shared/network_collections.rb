module ManageIQ::Providers::Openstack::Inventory::Persister::Shared::NetworkCollections
  extend ActiveSupport::Concern

  include ManageIQ::Providers::Openstack::Inventory::Persister::Shared::Utils

  def network
    ::ManagerRefresh::InventoryCollection::Builder::NetworkManager
  end

  def initialize_network_inventory_collections
    add_cloud_networks

    add_cloud_subnets

    add_cloud_subnet_network_ports

    add_firewall_rules

    add_floating_ips

    add_network_ports

    add_network_routers

    add_security_groups
  end

  # ------ IC provider specific definitions -------------------------

  # model_class defined due to ovirt dependency
  def add_cloud_networks
    add_collection(network, :cloud_networks) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork)

      ems_network_builder_param(builder)
    end
  end

  # model_class defined due to ovirt dependency
  def add_cloud_subnets
    add_collection(network, :cloud_subnets) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet)

      ems_network_builder_param(builder)
    end
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

  # model_class defined due to ovirt dependency
  def add_floating_ips
    add_collection(network, :floating_ips) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::Openstack::NetworkManager::FloatingIp)

      ems_network_builder_param(builder)
    end
  end

  def add_network_ports
    add_collection(network, :network_ports) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::Openstack::NetworkManager::NetworkPort)
      builder.add_properties(:delete_method => :disconnect_port)

      ems_network_builder_param(builder)
    end
  end

  # model_class defined due to ovirt dependency
  def add_network_routers
    add_collection(network, :network_routers) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::Openstack::NetworkManager::NetworkRouter)

      ems_network_builder_param(builder)
    end
  end

  # model_class defined due to ovirt dependency
  def add_security_groups
    add_collection(network, :security_groups) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::Openstack::NetworkManager::SecurityGroup)

      ems_network_builder_param(builder)
    end
  end
end

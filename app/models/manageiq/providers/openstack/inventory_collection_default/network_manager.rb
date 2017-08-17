class ManageIQ::Providers::Openstack::InventoryCollectionDefault::NetworkManager < ManagerRefresh::InventoryCollectionDefault::NetworkManager
  class << self
    def network_ports(extra_attributes = {})
      attributes = {
        :model_class                 => ::ManageIQ::Providers::Openstack::NetworkManager::NetworkPort,
        :association                 => :network_ports,
        :inventory_object_attributes => [
          :type,
          :name,
          :status,
          :admin_state_up,
          :mac_address,
          :device_owner,
          :device_ref,
          :device,
          :cloud_tenant,
          :binding_host_id,
          :binding_virtual_interface_type,
          :binding_virtual_interface_details,
          :binding_virtual_nic_type,
          :binding_profile,
          :extra_dhcp_opts,
          :allowed_address_pairs,
          :security_groups
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def network_routers(extra_attributes = {})
      attributes = {
        :model_class                 => ::ManageIQ::Providers::Openstack::NetworkManager::NetworkRouter,
        :association                 => :network_routers,
        :inventory_object_attributes => [
          :type,
          :name,
          :admin_state_up,
          :status,
          :external_gateway_info,
          :distributed,
          :routes,
          :high_availability,
          :cloud_tenant,
          :cloud_network
        ]
      }

      attributes.merge!(extra_attributes)
    end

    def floating_ips(extra_attributes = {})
      attributes = {
        :model_class                 => ManageIQ::Providers::Openstack::NetworkManager::FloatingIp,
        :association                 => :floating_ips,
        :inventory_object_attributes => [
          :type,
          :address,
          :fixed_ip_address,
          :status,
          :cloud_tenant,
          :cloud_network,
          :network_port,
          :vm
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def cloud_subnets(extra_attributes = {})
      attributes = {
        :model_class                 => ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet,
        :association                 => :cloud_subnets,
        :inventory_object_attributes => [
          :type,
          :name,
          :cidr,
          :status,
          :network_protocol,
          :gateway,
          :dhcp_enabled,
          :dns_nameservers,
          :ipv6_router_advertisement_mode,
          :ipv6_address_mode,
          :allocation_pools,
          :host_routes,
          :ip_version,
          :parent_cloud_subnet,
          :cloud_tenant,
          :cloud_network,
          :network_router
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def cloud_networks(extra_attributes = {})
      attributes = {
        :model_class                 => ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork,
        :association                 => :cloud_networks,
        :inventory_object_attributes => [
          :type,
          :name,
          :shared,
          :status,
          :enabled,
          :external_facing,
          :provider_physical_network,
          :provider_network_type,
          :provider_segmentation_id,
          :port_security_enabled,
          :qos_policy_id,
          :vlan_transparent,
          :maximum_transmission_unit,
          :cloud_tenant,
          :orchestration_stack
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def firewall_rules(extra_attributes = {})
      attributes = {
        :manager_ref                 => [:ems_ref],
        :inventory_object_attributes => [
          :resource,
          :source_security_group,
          :direction,
          :host_protocol,
          :network_protocol,
          :port,
          :end_port,
          :source_ip_range
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def security_groups(extra_attributes = {})
      attributes = {
        :model_class                 => ManageIQ::Providers::Openstack::NetworkManager::SecurityGroup,
        :association                 => :security_groups,
        :inventory_object_attributes => [
          :type,
          :name,
          :description,
          :cloud_tenant,
          :orchestration_stack
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def network_port_security_groups(extra_attributes = {})
      attributes = {
        :model_class => NetworkPortSecurityGroup,
        :manager_ref => [:security_group, :network_port],
        :association => :network_port_security_groups,
      }

      attributes.merge!(extra_attributes)
    end

    def cloud_subnet_network_ports(extra_attributes = {})
      attributes = {
        :model_class                  => CloudSubnetNetworkPort,
        :manager_ref                  => [:address, :cloud_subnet, :network_port],
        :association                  => :cloud_subnet_network_ports,
        :parent_inventory_collections => [:vms, :network_ports],
      }

      extra_attributes[:targeted_arel] = lambda do |inventory_collection|
        manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
        inventory_collection.parent.cloud_subnet_network_ports.references(:network_ports).where(
          :network_ports => {:ems_ref => manager_uuids}
        )
      end

      attributes.merge!(extra_attributes)
    end
  end
end

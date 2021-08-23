class ManageIQ::Providers::Openstack::Inventory::Parser::NetworkManager < ManageIQ::Providers::Openstack::Inventory::Parser
  include ManageIQ::Providers::Openstack::RefreshParserCommon::HelperMethods

  def parse
    cloud_networks
    cloud_subnets
    floating_ips
    network_ports
    network_routers
    security_groups
    firewall_rules
  end

  def cloud_networks
    collector.cloud_networks.each do |n|
      status = n["status"].to_s.downcase == "active" ? "active" : "inactive"

      network = persister.cloud_networks.find_or_build(n["id"])
      network.type = "#{persister.network_manager.class}::CloudNetwork::#{n["router:external"] ? "Public" : "Private"}"
      network.name = n["name"]
      network.shared = n["shared"]
      network.status = status
      network.enabled = n["admin_state_up"]
      network.external_facing = n["router:external"]
      network.provider_physical_network = n["provider:physical_network"]
      network.provider_network_type = n["provider:network_type"]
      network.provider_segmentation_id = n["provider:segmentation_id"]
      network.port_security_enabled = n["port_security_enabled"]
      network.qos_policy_id = n["qos_policy_id"]
      network.vlan_transparent = n["vlan_transparent"]
      network.maximum_transmission_unit = n["mtu"]
      network.cloud_tenant = persister.cloud_tenants.lazy_find(n["tenant_id"])
      network.orchestration_stack = persister.orchestration_stacks_resources.lazy_find(
        collector.orchestration_stack_by_resource_id(n["id"]).try(:physical_resource_id), :key => :stack
      )
    end
  end

  def cloud_subnets
    collector.cloud_subnets.each do |s|
      subnet = persister.cloud_subnets.find_or_build(s.id)
      subnet.name = s.name
      subnet.cidr = s.cidr
      subnet.network_protocol = "ipv#{s.ip_version}"
      subnet.gateway = s.gateway_ip
      subnet.dhcp_enabled = s.enable_dhcp
      subnet.dns_nameservers = s.dns_nameservers
      subnet.ipv6_router_advertisement_mode = s.attributes["ipv6_ra_mode"]
      subnet.ipv6_address_mode = s.attributes["ipv6_address_mode"]
      subnet.allocation_pools = s.allocation_pools
      subnet.host_routes = s.host_routes
      subnet.ip_version = s.ip_version
      if s.attributes["vsd_managed"]
        subnet.parent_cloud_subnet = persister.cloud_subnets.lazy_find(s.attributes["vsd_id"])
      end
      subnet.cloud_tenant = persister.cloud_tenants.lazy_find(s.tenant_id)
      subnet.cloud_network = persister.cloud_networks.lazy_find(s.network_id)
      subnet.status = persister.cloud_networks.lazy_find(s.network_id, :key => :status)
    end
  end

  def floating_ips
    collector.floating_ips.each do |f|
      floating_ip = persister.floating_ips.find_or_build(f.id)
      floating_ip.address = f.floating_ip_address
      floating_ip.fixed_ip_address = f.fixed_ip_address
      floating_ip.status = f.attributes["status"]
      floating_ip.cloud_tenant = persister.cloud_tenants.lazy_find(f.tenant_id)
      floating_ip.cloud_network = persister.cloud_networks.lazy_find(f.floating_network_id)
      floating_ip.network_port = persister.network_ports.lazy_find(f.port_id)
      floating_ip.vm = persister.network_ports.lazy_find(f.port_id, :key => :device)
    end
  end

  def network_ports
    collector.network_ports.each do |np|
      mac_address = np.mac_address

      network_port = persister.network_ports.find_or_build(np.id)
      network_port.name = np.name.blank? ? mac_address : np.name
      network_port.status = np.status
      network_port.admin_state_up = np.admin_state_up if np.admin_state_up.present?
      network_port.mac_address = mac_address
      network_port.device_owner = np.device_owner
      network_port.device_ref = np.device_id
      network_port.device = find_device_object(np)
      network_port.cloud_tenant = persister.cloud_tenants.lazy_find(np.tenant_id)
      network_port.binding_host_id = np.attributes["binding:host_id"]
      network_port.binding_virtual_interface_type = np.attributes["binding:vif_type"]
      network_port.binding_virtual_interface_details = np.attributes["binding:vif_details"]
      network_port.binding_virtual_nic_type = np.attributes["binding:vnic_type"]
      network_port.binding_profile = np.attributes["binding:profile"]
      network_port.extra_dhcp_opts = np.attributes["extra_dhcp_opts"]
      network_port.allowed_address_pairs = np.attributes["allowed_address_pairs"]

      security_groups = np.security_groups.map do |sg|
        persister.security_groups.lazy_find(sg)
      end
      network_port.security_groups = security_groups

      np.fixed_ips.each do |address|
        persister.cloud_subnet_network_ports.find_or_build_by(
          :address      => address["ip_address"],
          :cloud_subnet => persister.cloud_subnets.lazy_find(address["subnet_id"]),
          :network_port => network_port
        )
      end
    end
  end

  def network_routers
    collector.network_routers.each do |nr|
      network_id = nr.try(:external_gateway_info).try(:fetch_path, "network_id")
      network_router = persister.network_routers.find_or_build(nr.id)
      network_router.name = nr.name
      network_router.admin_state_up = nr.admin_state_up if nr.admin_state_up.present?
      network_router.status = nr.status
      network_router.external_gateway_info = nr.external_gateway_info
      network_router.distributed = nr.attributes["distributed"]
      network_router.routes = nr.attributes["routes"]
      network_router.high_availability = nr.attributes["ha"]
      network_router.cloud_tenant = persister.cloud_tenants.lazy_find(nr.tenant_id)
      network_router.cloud_network = persister.cloud_networks.lazy_find(network_id)
    end
  end

  def security_groups
    collector.security_groups.each do |s|
      security_group = persister.security_groups.find_or_build(s.id)
      security_group.name = s.name
      security_group.description = s.description.try(:truncate, 255)
      security_group.cloud_tenant = persister.cloud_tenants.lazy_find(s.tenant_id)
      security_group.orchestration_stack = persister.orchestration_stacks_resources.lazy_find(
        collector.orchestration_stack_by_resource_id(s.id).try(:physical_resource_id), :key => :stack
      )

      s.security_group_rules.each do |r|
        next unless collector.network_service.name == :nova

        firewall_rule_nova(r, security_group)
        # Neutron security group rules are handled as s separate firewall_rules collection
      end
    end
  end

  def firewall_rule_neutron(rule, security_group)
    direction = rule.direction == "egress" ? "outbound" : "inbound"
    firewall_rule = persister.firewall_rules.find_or_build(rule.id)
    firewall_rule.resource = security_group
    firewall_rule.source_security_group = persister.security_groups.lazy_find(rule.remote_group_id)
    firewall_rule.direction = direction
    firewall_rule.host_protocol = rule.protocol.to_s.upcase
    firewall_rule.port = rule.port_range_min
    firewall_rule.end_port = rule.port_range_max
    firewall_rule.source_ip_range = rule.remote_ip_prefix
    firewall_rule.network_protocol = rule.ethertype.to_s.upcase
  end

  def firewall_rule_nova(rule, security_group)
    firewall_rule = persister.firewall_rules.find_or_build(rule.id)
    firewall_rule.resource = security_group
    firewall_rule.source_security_group = persister.security_groups.lazy_find(collector.security_groups_by_name[rule.group["name"]])
    firewall_rule.direction = "inbound"
    firewall_rule.host_protocol = rule.ip_protocol.to_s.upcase
    firewall_rule.port = rule.from_port
    firewall_rule.end_port = rule.to_port
    firewall_rule.source_ip_range = rule.ip_range["cidr"]
  end

  def firewall_rules
    collector.firewall_rules.each do |s|
      firewall_rule_neutron(s, persister.security_groups.find_or_build(s.security_group_id))
    end
  end

  def find_device_object(network_port)
    case network_port.device_owner
    when /^compute\:.*?$/
      # Owner is in format compute:<availability_zone> or compute:None
      # TODO(slucidi): replace this query for hosts once the infra manager uses the graph inventory system
      host = collector.manager.hosts.where(:uid_ems => network_port.device_id).first
      return host || persister.vms.lazy_find(network_port.device_id)
    when "network:router_interface", "network:router_ha_interface", "network:ha_router_replicated_interface", "network:router_interface_distributed"
      subnet_id = network_port.fixed_ips.try(:first).try(:[], "subnet_id")
      if subnet_id
        subnet = persister.cloud_subnets.find_or_build(subnet_id)
        return subnet.network_router = persister.network_routers.lazy_find(network_port.device_id)
      end
    end
    # Returning nil for non VM port, we don't want to store those as ports
    nil
  end
end

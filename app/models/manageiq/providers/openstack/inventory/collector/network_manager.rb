class ManageIQ::Providers::Openstack::Inventory::Collector::NetworkManager < ManageIQ::Providers::Openstack::Inventory::Collector
  include ManageIQ::Providers::Openstack::Inventory::Collector::HelperMethods

  def floating_ips
    return @floating_ips if @floating_ips.any?
    @floating_ips = network_service.handled_list(:floating_ips, {}, openstack_network_admin?)
  end

  def cloud_networks
    return @cloud_networks if @cloud_networks.any?
    @cloud_networks = safe_list { network_service.list_networks.body["networks"] }
  end

  def cloud_subnets
    return @cloud_subnets if @cloud_subnets.any?
    @cloud_subnets = network_service.handled_list(:subnets, {}, openstack_network_admin?)
  end

  def network_ports
    return @network_ports if @network_ports.any?
    @network_ports = network_service.handled_list(:ports, {}, openstack_network_admin?)
  end

  def network_routers
    return @network_routers if @network_routers.any?
    @network_routers = network_service.handled_list(:routers, {}, openstack_network_admin?)
  end

  def security_groups
    return @security_groups if @security_groups.any?
    @security_groups = network_service.handled_list(:security_groups, {}, openstack_network_admin?)
  end

  def security_groups_by_name
    @security_groups_by_name ||= Hash[security_groups.collect { |sg| [sg.name, sg.id] }]
  end

  def firewall_rules
    return @firewall_rules if @firewall_rules.any?

    @firewall_rules = network_service.handled_list(:security_group_rules, {}, openstack_network_admin?)
  end

  def orchestration_stacks
    return [] unless orchestration_service
    # TODO(lsmola) We need a support of GET /{tenant_id}/stacks/detail in FOG, it was implemented here
    # https://review.openstack.org/#/c/35034/, but never documented in API reference, so right now we
    # can't get list of detailed stacks in one API call.
    return @orchestration_stacks unless @orchestration_stacks.nil?
    @orchestration_stacks = if openstack_heat_global_admin?
                                orchestration_service.handled_list(:stacks, {:show_nested => true, :global_tenant => true}, true).collect(&:details)
                              else
                                orchestration_service.handled_list(:stacks, :show_nested => true).collect(&:details)
                              end
  rescue Excon::Errors::Forbidden
    # Orchestration service is detected but not open to the user
    $log.warn("Skip refreshing stacks because the user cannot access the orchestration service")
    []
  end

  def orchestration_resources(stack)
    @os_handle ||= manager.openstack_handle
    safe_list { stack.resources }
  end
end

class ManageIQ::Providers::Openstack::Inventory::Collector::NetworkManager < ManageIQ::Providers::Openstack::Inventory::Collector
  def floating_ips
    return @floating_ips if @floating_ips.any?
    @floating_ips = network_service.handled_list(:floating_ips, {}, ::Settings.ems.ems_openstack.refresh.is_admin)
  end

  def cloud_networks
    return @cloud_networks if @cloud_networks.any?
    @cloud_networks = network_service.handled_list(:networks, {}, ::Settings.ems.ems_openstack.refresh.is_admin)
  end

  def network_ports
    return @network_ports if @network_ports.any?
    @network_ports = network_service.handled_list(:ports, {}, ::Settings.ems.ems_openstack.refresh.is_admin)
  end

  def network_routers
    return @network_routers if @network_routers.any?
    @network_routers = network_service.handled_list(:routers, {}, ::Settings.ems.ems_openstack.refresh.is_admin)
  end

  def security_groups
    return @security_groups if @security_groups.any?
    @security_groups = network_service.handled_list(:security_groups, {}, ::Settings.ems.ems_openstack.refresh.is_admin)
  end

  def security_groups_by_name
    @security_groups_by_name ||= Hash[security_groups.collect { |sg| [sg.name, sg.id] }]
  end

  def orchestration_stacks
    return [] unless orchestration_service
    # TODO(lsmola) We need a support of GET /{tenant_id}/stacks/detail in FOG, it was implemented here
    # https://review.openstack.org/#/c/35034/, but never documented in API reference, so right now we
    # can't get list of detailed stacks in one API call.
    return @orchestration_stacks if @orchestration_stacks.any?
    @orchestration_stacks = if ::Settings.ems.ems_openstack.refresh.heat.is_global_admin
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

  def orchestration_stack_by_resource_id(resource_id)
    @resources ||= {}
    if @resources.empty?
      orchestration_stacks.each do |stack|
        resources = orchestration_resources(stack)
        resources.each do |r|
          @resources[r.physical_resource_id] = r
        end
      end
    end
    @resources[resource_id]
  end
end

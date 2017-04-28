class ManageIQ::Providers::Openstack::Inventory::Collector::NetworkManager < ManagerRefresh::Inventory::Collector
  include ManageIQ::Providers::Openstack::RefreshParserCommon::HelperMethods
  include Vmdb::Logging

  def connection
    @os_handle ||= manager.openstack_handle
    @connection ||= manager.connect
  end

  def network_service
    @network_service ||= manager.openstack_handle.detect_network_service
  end

  def orchestration_service
    @orchestration_service ||= manager.openstack_handle.detect_orchestration_service
  end

  def floating_ips
    @floating_ips ||= network_service.handled_list(:floating_ips)
  end

  def cloud_networks
    @cloud_networks ||= network_service.handled_list(:networks)
  end

  def network_ports
    @network_ports ||= network_service.handled_list(:ports)
  end

  def network_routers
    @network_routers ||= network_service.handled_list(:routers)
  end

  def security_groups
    @security_groups ||= network_service.handled_list(:security_groups)
  end

  def security_groups_by_name
    @security_groups_by_name ||= Hash[security_groups.collect { |sg| [sg.name, sg.id] }]
  end

  def orchestration_stacks
    return [] unless orchestration_service
    # TODO(lsmola) We need a support of GET /{tenant_id}/stacks/detail in FOG, it was implemented here
    # https://review.openstack.org/#/c/35034/, but never documented in API reference, so right now we
    # can't get list of detailed stacks in one API call.
    @orchestration_stacks ||= orchestration_service.handled_list(:stacks, :show_nested => true).collect(&:details)
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

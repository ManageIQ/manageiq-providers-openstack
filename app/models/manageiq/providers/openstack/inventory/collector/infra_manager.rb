class ManageIQ::Providers::Openstack::Inventory::Collector::InfraManager < ManageIQ::Providers::Openstack::Inventory::Collector::FullCollection
  def orchestration_resources(stack)
    super.reject { |r| r.physical_resource_id.nil? }
  end

  def stack_server_resource_types
    return @stack_server_resource_types if @stack_server_resource_types

    @stack_server_resource_types = ["OS::TripleO::Server", "OS::Nova::Server"]
    @stack_server_resource_types += stack_resource_groups.map { |rg| "OS::TripleO::" + rg["resource_name"] + "Server" }
  end

  def stack_server_resources
    @stack_server_resources ||= filter_stack_resources_by_resource_type(stack_server_resource_types)
  end

  def server_purpose_by_instance_uuid
    @server_purpose_by_instance_uuid ||= Hash[stack_server_resources.map { |res| [res['physical_resource_id'], res['resource_name']] }]
  end

  private

  def validate_required_services
    unless identity_service
      raise MiqException::MiqOpenstackKeystoneServiceMissing, "Required service Keystone is missing in the catalog."
    end

    unless compute_service
      raise MiqException::MiqOpenstackNovaServiceMissing, "Required service Nova is missing in the catalog."
    end

    unless image_service
      raise MiqException::MiqOpenstackGlanceServiceMissing, "Required service Glance is missing in the catalog."
    end

    # log a warning but don't fail on missing Ironic
    unless baremetal_service
      _log.warn "Ironic service is missing in the catalog. No host data will be synced."
    end
  end

  def stack_resources(stack)
    # TODO(lsmola) loading this from already obtained nested stack hierarchy will be more effective. This is one
    # extra API call. But we will need to change order of loading, so we have all resources first.
    @stack_resources ||= orchestration_service.list_resources(:stack => stack, :nested_depth => 2).body['resources']
  end

  def filter_stack_resources_by_resource_type(resource_type_list)
    resources = []
    root_stacks.each do |stack|
      # Filtering just server resources which is important to us for getting Purpose of the node
      # (compute, controller, etc.).
      resources += stack_resources(stack).select { |x| resource_type_list.include?(x["resource_type"]) }
    end
    resources
  end

  def stack_resource_groups
    @stack_resource_groups ||= filter_stack_resources_by_resource_type(["OS::Heat::ResourceGroup"])
  end
end

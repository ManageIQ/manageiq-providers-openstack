module ManageIQ::Providers::Openstack::Inventory::Collector::HelperMethods
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

  def tenant_ids_with_flavor_access(flavor_id)
    unparsed_tenants = safe_get { connection.list_tenants_with_flavor_access(flavor_id) }
    flavor_access = unparsed_tenants.try(:data).try(:[], :body).try(:[], "flavor_access") || []
    flavor_access.map! { |t| t['tenant_id'] }
  rescue
    []
  else
    flavor_access
  end
end

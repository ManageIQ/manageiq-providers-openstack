class ManageIQ::Providers::Openstack::Inventory::Collector::InfraManager < ManageIQ::Providers::Openstack::Inventory::Collector
  include ManageIQ::Providers::Openstack::Inventory::Collector::HelperMethods

  def servers
    return @servers if @servers.any?
    @servers = uniques(connection.handled_list(:servers))
  end

  def hosts
    return @hosts if @hosts.any?
    @hosts = uniques(baremetal_service.handled_list(:nodes))
  end

  def servers_by_id
    @servers_by_id ||= servers.index_by(&:id)
  end

  def object_store
    return if storage_service.blank? || storage_service.name != :swift
    @object_store ||= storage_service.handled_list(:directories)
  end

  def get_introspection_details(host_uuid)
    return {} unless introspection_service
    begin
      introspection_service.get_introspection_details(host_uuid).body
    rescue
      # introspection data not available
      {}
    end
  end

  def tenants
    return @tenants if @tenants.any?
    @tenants = manager.openstack_handle.tenants
  end

  def root_stacks
    return @root_stacks if @root_stacks.any?
    @root_stacks = uniques(orchestration_stacks(false))
  end

  def stack_server_resources
    return @stack_server_resources if @stack_server_resources.any?
    @stack_server_resources = filter_stack_resources_by_resource_type(stack_server_resource_types)
  end

  def stack_server_resource_types
    return @stack_server_resource_types if @stack_server_resource_types.any?
    @stack_server_resource_types = ["OS::TripleO::Server", "OS::Nova::Server"]
    @stack_server_resource_types += stack_resource_groups.map { |rg| "OS::TripleO::" + rg["resource_name"] + "Server" }
  end

  def filter_stack_resources_by_resource_type(resource_type_list)
    resources = []
    root_stacks.each do |stack|
      # Filtering just server resources which is important to us for getting Purpose of the node
      # (compute, controller, etc.).
      resources += stack_resources_by_depth(stack).select do |x|
        resource_type_list.include?(x["resource_type"])
      end
    end
    resources
  end

  def stack_resource_groups
    @stack_resource_groups ||= filter_stack_resources_by_resource_type(["OS::Heat::ResourceGroup"])
  end

  def stack_resources_by_depth(stack)
    # TODO(lsmola) loading this from already obtained nested stack hierarchy will be more effective. This is one
    # extra API call. But we will need to change order of loading, so we have all resources first.
    @stack_resources ||= @orchestration_service.list_resources(:stack => stack, :nested_depth => 2).body['resources']
  end

  def cloud_ems_hosts_attributes
    clouds = @manager.provider.try(:cloud_ems)

    hosts_attributes = []
    return hosts_attributes unless clouds
    clouds.each do |cloud_ems|
      compute_hosts = nil
      begin
        cloud_ems.with_provider_connection do |connection|
          compute_hosts = connection.hosts.select { |x| x.service_name == "compute" }
        end
      rescue => err
        _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
        _log.error(err.backtrace.join("\n"))
        # Just log the error and continue the refresh, we don't want error in cloud side to affect infra refresh
        next
      end

      compute_hosts.each do |compute_host|
        # We need to take correct zone id from correct provider, since the zone name can be the same
        # across providers
        availability_zone_id = cloud_ems.availability_zones.find_by(:name => compute_host.zone).try(:id)
        hosts_attributes << {:host_name => compute_host.host_name, :availability_zone_id => availability_zone_id}
      end
    end
    hosts_attributes
  end
end

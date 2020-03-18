class ManageIQ::Providers::Openstack::Inventory::Collector::InfraManager < ManageIQ::Providers::Openstack::Inventory::Collector
  include ManageIQ::Providers::Openstack::Inventory::Collector::HelperMethods

  def initialize(_manager, _target)
    super

    validate_required_services
  end

  def baremetal_service
    @baremetal_service ||= manager.openstack_handle.detect_baremetal_service
  end

  def introspection_service
    @introspection_service ||= manager.openstack_handle.detect_introspection_service
  end

  def servers
    return [] unless compute_service
    return @servers if @servers.any?

    @servers = uniques(compute_service.handled_list(:servers))
  end

  def servers_by_id
    @servers_by_id ||= servers.index_by(&:id)
  end

  def hosts
    return [] unless baremetal_service
    return @hosts if @hosts.any?

    @hosts = uniques(baremetal_service.handled_list(:nodes))
  end

  def cloud_managers
    @cloud_managers ||= (manager.provider&.cloud_ems || [])
  end

  def clusters
    @cluster_by_host ||= {}
    @clusters ||= begin
      orchestration_stacks.each_with_object([]) do |stack, arr|
        parent = indexed_orchestration_stacks[stack.parent]
        next unless parent

        nova_server = stack.resources.detect { |r| stack_server_resource_types.include?(r.resource_type) }
        next unless nova_server

        @cluster_by_host[nova_server.physical_resource_id] = parent.id
        arr << {:name => parent.stack_name, :uid => parent.id}
      end
    end
  end

  def cluster_by_host
    clusters if @cluster_by_host.nil?
    @cluster_by_host
  end

  def cloud_host_attributes
    @cloud_host_attributes ||= begin
      cloud_managers.flat_map do |cloud_ems|
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

        compute_hosts.map do |compute_host|
          # We need to take correct zone id from correct provider, since the zone name can be the same
          # across providers
          availability_zone_id = cloud_ems.availability_zones.find_by(:name => compute_host.zone).try(:id)
          {:host_name => compute_host.host_name, :availability_zone_id => availability_zone_id}
        end
      end
    end
  end

  def introspection_details(host)
    return {} unless introspection_service

    begin
      introspection_service.get_introspection_details(host.uuid).body
    rescue
      {}
    end
  end

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

class ManageIQ::Providers::Openstack::Inventory::Collector::InfraManager < ManageIQ::Providers::Openstack::Inventory::Collector
  include ManageIQ::Providers::Openstack::Inventory::Collector::HelperMethods

  def initialize(_manager, _target)
    super

    validate_required_services
  end

  def baremetal_service
    @baremetal_service ||= manager.openstack_handle.detect_baremetal_service
  end

  def storage_service
    @storage_service ||= manager.openstack_handle.detect_storage_service
  end

  def introspection_service
    @introspection_service ||= manager.openstack_handle.detect_introspection_service
  end

  def images
    return [] unless image_service
    return @images if @images.any?

    @images = uniques(image_service.handled_list(:images))
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

  def stacks
    @stacks ||= uniques(detailed_stacks)
  end

  def stacks_by_id
    @stacks_by_id ||= stacks.index_by(&:id)
  end

  def root_stacks
    @root_stacks ||= uniques(detailed_stacks(false))
  end

  def cloud_managers
    @cloud_managers ||= (manager.provider&.cloud_ems || [])
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

  def cloud_host_attributes_by_host
    @cloud_host_attributes_by_host ||= cloud_host_attributes.group_by do |host_attrs|
      host_attrs[:host_name]
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

  def detailed_stacks(show_nested = true)
    return [] unless orchestration_service

    # TODO(lsmola) We need a support of GET /{tenant_id}/stacks/detail in FOG, it was implemented here
    # https://review.openstack.org/#/c/35034/, but never documented in API reference, so right now we
    # can't get list of detailed stacks in one API call.
    orchestration_service.handled_list(:stacks, :show_nested => show_nested).collect(&:details)
  rescue Excon::Errors::Forbidden
    # Orchestration service is detected but not open to the user
    _log.warn("Skip refreshing stacks because the user cannot access the orchestration service")
    []
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

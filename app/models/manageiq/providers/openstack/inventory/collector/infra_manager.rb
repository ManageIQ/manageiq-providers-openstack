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

  def hosts
    return [] unless baremetal_service
    return @hosts if @hosts.any?

    @hosts = uniques(baremetal_service.handled_list(:nodes))
  end

  def stacks
    @stacks ||= uniques(detailed_stacks)
  end

  def root_stacks
    @root_stacks ||= uniques(detailed_stacks(false))
  end

  def cloud_managers
    @cloud_managers ||= (manager.provider&.cloud_ems || [])
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
end

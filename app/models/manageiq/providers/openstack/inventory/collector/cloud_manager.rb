class ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager < ManageIQ::Providers::Openstack::Inventory::Collector
  include ManageIQ::Providers::Openstack::Inventory::Collector::HelperMethods

  def availability_zones
    return @availability_zones if @availability_zones.any?
    @availability_zones = safe_list { compute_service.availability_zones.summary }
  end

  def cloud_services
    return @cloud_services if @cloud_services.any?
    @cloud_services = compute_service.handled_list(:services, {}, openstack_admin?)
  end

  def flavors
    return @flavors if @flavors.any?
    flavors = connection.handled_list(:flavors, {'is_public' => 'None'}, true)
    @flavors = flavors
  end

  def find_flavor(flavor_id)
    flavor = flavors_by_id[flavor_id]
    if flavor.nil?
      # the flavor might be private, which the flavor list api
      # doesn't seem to handle correctly. Try to get it separately.
      flavor = private_flavor(flavor_id)
    end
    flavor
  end

  def private_flavor(flavor_id)
    flavor = safe_get { connection.flavors.get(flavor_id) }
    if flavor
      flavors_by_id[flavor_id] = flavor
    end
  end

  def flavors_by_id
    @flavors_by_id ||= Hash[flavors.collect { |f| [f.id, f] }]
  end

  def host_aggregates
    return @host_aggregates if @host_aggregates.any?
    @host_aggregates = safe_list { compute_service.aggregates.all }
  end

  def images
    return [] unless image_service
    return @images if @images.any?
    @images = if openstack_admin?
                image_service.images_with_pagination_loop
              else
                image_service.handled_list(:images)
              end
  end

  def key_pairs
    return @key_pairs if @key_pairs.any?
    @key_pairs = compute_service.handled_list(:key_pairs, {}, openstack_admin?)
  end

  def quotas
    quotas = safe_list { compute_service.quotas_for_accessible_tenants }
    quotas.concat(safe_list { volume_service.quotas_for_accessible_tenants }) if volume_service
    # TODO(lsmola) can this somehow be moved under NetworkManager
    quotas.concat(safe_list { network_service.quotas_for_accessible_tenants }) if network_service
    quotas
  end

  def vms
    return @vms if @vms.any?
    @vms = compute_service.handled_list(:servers, {}, openstack_admin?)
  end

  def vms_by_id
    @vms_by_id ||= vms.index_by(&:id)
  end

  def tenants
    return @tenants if @tenants.any?
    @tenants = manager.openstack_handle.tenants.select do |t|
      # avoid 401 Unauth errors when checking for accessible tenants
      # the "services" tenant is a special tenant in openstack reserved
      # specifically for the various services
      next if t.name == "services"
      true
    end
  end

  def vnfs
    return [] unless nfv_service
    return @vnfs if @vnfs.any?
    @vnfs = nfv_service.handled_list(:vnfs, {}, openstack_admin?)
  end

  def vnfds
    return [] unless nfv_service
    return @vnfds if @vnfds.any?
    @vnfds = nfv_service.handled_list(:vnfds, {}, openstack_admin?)
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

  def orchestration_outputs(stack)
    safe_list { stack.outputs }
  end

  def orchestration_parameters(stack)
    safe_list { stack.parameters }
  end

  def orchestration_resources(stack)
    safe_list { stack.resources }
  end

  def orchestration_template(stack)
    safe_call { stack.template }
  end

  def volume_templates
    return [] unless volume_service
    return @volume_templates if @volume_templates.any?
    @volume_templates = volume_service.handled_list(:volumes, {:status => "available"}, openstack_admin?)
  end

  def volumes_by_id
    return [] unless volume_service
    # collect even unavailable volumes since they're just being used to identify
    # whether a given snapshot is based on a bootable volume-- the volume's current
    # status doesn't matter.
    @volumes_by_id ||= volume_service.handled_list(:volumes, {}, openstack_admin?).index_by(&:id)
  end

  def volume_snapshot_templates
    return [] unless volume_service
    return @volume_snapshot_templates if @volume_snapshot_templates.any?
    @volume_snapshot_templates = volume_service.handled_list(:list_snapshots_detailed, {:status => "available", :__request_body_index => "snapshots"}, openstack_admin?).select do |s|
      volumes_by_id[s["volume_id"]] && (volumes_by_id[s["volume_id"]].attributes["bootable"].to_s == "true")
    end
  end
end

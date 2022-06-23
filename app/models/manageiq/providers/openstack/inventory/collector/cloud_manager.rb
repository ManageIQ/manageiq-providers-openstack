class ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager < ManageIQ::Providers::Openstack::Inventory::Collector
  include ManageIQ::Providers::Openstack::Inventory::Collector::HelperMethods

  def availability_zones_compute
    return @availability_zones_compute if @availability_zones_compute.any?
    @availability_zones_compute = safe_list { compute_service.availability_zones.summary }
    @availability_zones_compute = @availability_zones_compute.collect(&:zoneName).to_set
  end

  def availability_zones_volume
    return [] unless volume_service
    return @availability_zones_volume if @availability_zones_volume.any?
    @availability_zones_volume = safe_list { volume_service.availability_zones.summary }
    @availability_zones_volume = @availability_zones_volume.collect(&:zoneName).to_set
  end

  def availability_zones
    @availability_zones ||= (availability_zones_compute + availability_zones_volume).to_set
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

  def placement_group_by_vm_id
    @placement_group_by_vm_id ||= placement_groups.each_with_object({}) { |sg, result| sg.members.each { |vm_id| result[vm_id] = sg } }
  end

  def placement_groups
    return @placement_groups if @placement_group && @placement_groups.any?

    @placement_groups = compute_service.handled_list(:server_groups, {}, openstack_admin?)
  end

  def server_group_by_vm_id
    return @server_group_by_vm_id if @server_group_by_vm_id && @server_group_by_vm_id.any?

    @server_group_by_vm_id ||= server_groups.each_with_object({}) { |sg, result| sg.members.each { |vm_id| result[vm_id] = sg } }
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

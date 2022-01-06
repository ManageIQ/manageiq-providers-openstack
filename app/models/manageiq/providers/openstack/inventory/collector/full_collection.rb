class ManageIQ::Providers::Openstack::Inventory::Collector::FullCollection < ManageIQ::Providers::Openstack::Inventory::Collector
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
    @flavors_by_id ||= flavors.index_by(&:id)
  end

  def host_aggregates
    return @host_aggregates if @host_aggregates.any?

    @host_aggregates = safe_list { compute_service.aggregates.all }
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

  def floating_ips
    return @floating_ips if @floating_ips.any?

    @floating_ips = network_service.handled_list(:floating_ips, {}, openstack_network_admin?)
  end

  def cloud_networks
    return @cloud_networks if @cloud_networks.any?

    @cloud_networks = safe_list { network_service.list_networks.body["networks"] }
  end

  def cloud_subnets
    return @cloud_subnets if @cloud_subnets.any?

    @cloud_subnets = network_service.handled_list(:subnets, {}, openstack_network_admin?)
  end

  def network_ports
    return @network_ports if @network_ports.any?

    @network_ports = network_service.handled_list(:ports, {}, openstack_network_admin?)
  end

  def network_routers
    return @network_routers if @network_routers.any?

    @network_routers = network_service.handled_list(:routers, {}, openstack_network_admin?)
  end

  def security_groups
    return @security_groups if @security_groups.any?

    @security_groups = network_service.handled_list(:security_groups, {}, openstack_network_admin?)
  end

  def security_groups_by_name
    @security_groups_by_name ||= Hash[security_groups.collect { |sg| [sg.name, sg.id] }]
  end

  def firewall_rules
    return @firewall_rules if @firewall_rules.any?

    @firewall_rules = network_service.handled_list(:security_group_rules, {}, openstack_network_admin?)
  end

  def cloud_volumes
    return [] unless volume_service
    return @cloud_volumes if @cloud_volumes.any?

    @cloud_volumes = volume_service.handled_list(:volumes, {}, cinder_admin?)
  end

  def cloud_volume_snapshots
    return [] unless volume_service
    return @cloud_volume_snapshots if @cloud_volume_snapshots.any?

    @cloud_volume_snapshots = volume_service.handled_list(:list_snapshots_detailed, {:__request_body_index => "snapshots"}, cinder_admin?)
  end

  def cloud_volume_backups
    return [] unless volume_service
    return @cloud_volume_backups if @cloud_volume_backups.any?

    @cloud_volume_backups = volume_service.handled_list(:list_backups_detailed, {:__request_body_index => "backups"}, cinder_admin?)
  end

  def cloud_volume_types
    return [] unless volume_service
    return @cloud_volume_types if @cloud_volume_types.any?

    @cloud_volume_types = volume_service.handled_list(:volume_types, {}, cinder_admin?)
  end

  def directories
    return [] unless swift_service

    @directories ||= swift_service.handled_list(:directories)
  end

  def files(directory)
    safe_list { directory.files }
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
      manager.provider&.cloud_ems.to_a.flat_map do |cloud_ems|
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
end

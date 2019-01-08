class ManageIQ::Providers::Openstack::Inventory::Parser::InfraManager < ManageIQ::Providers::Openstack::Inventory::Parser
  include ManageIQ::Providers::Openstack::RefreshParserCommon::HelperMethods
  include ManageIQ::Providers::Openstack::RefreshParserCommon::Images
  include ManageIQ::Providers::Openstack::Inventory::Parser::CommonMethods

  def parse
    object_store
    hosts
    clusters
    cloud_tenants
    miq_templates("ManageIQ::Providers::Openstack::InfraManager::Template")
    orchestration_stacks("ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack")
  end

  def object_store
    collector.object_store.each do |dir|
      container_uid          = "#{dir.project.id}/#{dir.key}"
      container              = persister.cloud_object_store_containers.find_or_build(container_uid)
      container.ems_ref      = container_uid
      container.key          = dir.key
      container.object_count = dir.count
      container.bytes        = dir.bytes
      container.cloud_tenant = persister.cloud_tenants.lazy_find(dir.project.id)

      dir.files.each do |obj|
        file_uid                             = obj.key
        file                                 = persister.cloud_object_store_objects.find_or_build(file_uid)
        file.ems_ref                         = file_uid
        file.etag                            = obj.etag
        file.last_modified                   = obj.last_modified
        file.content_length                  = obj.content_length
        file.key                             = obj.key
        file.content_type                    = obj.content_type
        file.cloud_object_store_container    = container
        file.cloud_tenant                    = persister.cloud_tenants.lazy_find(obj.project.id) if obj.project
      end
    end
  end

  def hosts
    # Servers contains assigned IP address of hosts, there can be only
    # one nova server per host, only if the host is provisioned.
    indexed_servers = {}
    collector.servers.each { |s| indexed_servers[s.id] = s }
    # Indexed Heat resources, we are interested only in OS::Nova::Server/OS::TripleO::Server
    indexed_resources = {}
    collector.stack_server_resources.each { |p| indexed_resources[p['physical_resource_id']] = p }

    collector.hosts.each do |h|
      uid                   = h.uuid
      host                  = persister.hosts.find_or_build(uid)
      name                  = identify_host_name(indexed_resources, h.instance_uuid, uid)
      ip_address            = identify_primary_ip_address(indexed_servers, h.instance_uuid)
      hostname              = ip_address
      introspection_details = collector.get_introspection_details(h.uuid)
      extra_attributes      = get_extra_attributes(introspection_details)
      hypervisor_hostname   = identify_hypervisor_hostname(indexed_servers, h)

      # Get the cloud_host_attributes by hypervisor hostname, only compute hosts can get this
      cloud_host_attributes = collector.cloud_ems_hosts_attributes.select do |x|
        hypervisor_hostname && x[:host_name].include?(hypervisor_hostname.downcase)
      end
      cloud_host_attributes = cloud_host_attributes.first if cloud_host_attributes

      host.name                     = name
      host.type                     = 'ManageIQ::Providers::Openstack::InfraManager::Host'
      host.uid_ems                  = uid
      host.ems_ref                  = uid
      host.ems_ref_obj              = h.instance_uuid
      operating_system              = persister.operating_systems.find_or_build(host)
      operating_system.product_name = 'linux'
      host.operating_system         = operating_system
      host.vmm_vendor               = 'redhat'
      host.vmm_product              = identify_product(indexed_resources, h.instance_uuid)
      # Can't get this from ironic, maybe from Glance metadata, when it will be there, or image fleecing?
      host.vmm_version              = nil
      host.ipaddress                = ip_address
      host.hostname                 = hostname
      host.mac_address              = identify_primary_mac_address(indexed_servers, h.instance_uuid)
      host.ipmi_address             = identify_ipmi_address(h)
      host.power_state              = lookup_power_state(host.power_state)
      host.connection_state         = lookup_connection_state(host.power_state)
      host.maintenance              = h.maintenance
      host.maintenance_reason       = h.maintenance_reason
      host.hardware                 = process_host_hardware(h, host, introspection_details, extra_attributes)
      host.hypervisor_hostname      = hypervisor_hostname
      host.service_tag              = extra_attributes.fetch_path('system', 'product', 'serial')
      host.availability_zone_id     = cloud_host_attributes.try(:[], :availability_zone_id)
    end
  end

  def clusters
    clusters, cluster_host_mapping = clusters_and_host_mapping
    clusters.each do |c|
      name            = c[:name]
      uid             = c[:uid]
      cluster         = persister.ems_clusters.find_or_build(uid)
      cluster.ems_ref = uid
      cluster.uid_ems = uid
      cluster.name    = name
      cluster.type    = 'ManageIQ::Providers::Openstack::InfraManager::EmsCluster'
    end

    cluster_host_mapping.each do |host_ems_ref, cluster_ems_ref|
      host = persister.hosts.find_or_build(host_ems_ref)
      host.ems_cluster = persister.ems_clusters.lazy_find(cluster_ems_ref)
    end
  end

  def identify_host_name(indexed_resources, instance_uuid, uid)
    purpose = get_purpose(indexed_resources, instance_uuid)
    return uid unless purpose
    "#{uid} (#{purpose})"
  end

  def identify_product(indexed_resources, instance_uuid)
    purpose = get_purpose(indexed_resources, instance_uuid)
    return nil unless purpose
    if purpose == 'NovaCompute'
      'rhel (Nova Compute hypervisor)'
    else
      "rhel (No hypervisor, Host Type is #{purpose})"
    end
  end

  def get_purpose(indexed_resources, instance_uuid)
    indexed_resources.fetch_path(instance_uuid, 'resource_name')
  end

  def identify_primary_ip_address(indexed_servers, instance_uuid)
    server_address(indexed_servers[instance_uuid], 'addr')
  end

  def identify_primary_mac_address(indexed_servers, instance_uuid)
    server_address(indexed_servers[instance_uuid], 'OS-EXT-IPS-MAC:mac_addr')
  end

  def identify_hypervisor_hostname(indexed_servers, instance_uuid)
    indexed_servers.fetch_path(instance_uuid).try(:name)
  end

  def server_address(server, key)
    # TODO(lsmola) Nova is missing information which address is primary now,
    # so just taking first. We need to figure out how to identify it if
    # there are multiple.
    server&.addresses&.fetch_path('ctlplane', 0, key)
  end

  def identify_ipmi_address(host)
    host.driver_info["ipmi_address"]
  end

  def lookup_power_state(power_state_input)
    case power_state_input
    when "power on"               then "on"
    when "power off", "rebooting" then "off"
    else                               "unknown"
    end
  end

  def lookup_connection_state(power_state_input)
    case power_state_input
    when "power on"               then "connected"
    when "power off", "rebooting" then "disconnected"
    else                               "disconnected"
    end
  end

  def process_host_hardware(host, host_inventory, introspection_details, extra_attributes)
    hardware = persister.hardwares.find_or_build(host_inventory)

    cpu_sockets          = extra_attributes.fetch_path('cpu', 'physical', 'number').to_i
    cpu_total_cores      = extra_attributes.fetch_path('cpu', 'logical', 'number').to_i
    cpu_cores_per_socket = cpu_sockets.positive? ? cpu_total_cores / cpu_sockets : 0
    cpu_speed            = introspection_details.fetch_path('inventory', 'cpu', 'frequency').to_i

    hardware.memory_mb            = host.properties['memory_mb']
    hardware.disk_capacity        = host.properties['local_gb']
    hardware.cpu_total_cores      = cpu_total_cores
    hardware.cpu_sockets          = cpu_sockets
    hardware.cpu_cores_per_socket = cpu_cores_per_socket
    hardware.cpu_speed            = cpu_speed
    hardware.cpu_type             = extra_attributes.fetch_path('cpu', 'physical_0', 'version')
    hardware.manufacturer         = extra_attributes.fetch_path('system', 'product', 'vendor')
    hardware.model                = extra_attributes.fetch_path('system', 'product', 'name')
    hardware.number_of_nics       = extra_attributes.fetch_path('network').try(:keys).try(:count).to_i
    hardware.bios                 = extra_attributes.fetch_path('firmware', 'bios', 'version')
    # Can't get these 2 from ironic, maybe from Glance metadata, when it will be there, or image fleecing?
    hardware.guest_os_full_name   = nil
    hardware.guest_os             = nil
    hardware.disks                = process_host_hardware_disks(hardware, extra_attributes)
    hardware.introspected         = introspection_details.present?
    # fog-openstack baremetal service defaults to Ironic API v1.1.
    # In version 1.1 "available" is shown as null in JSON. It is correctly
    # shown as "available" starting with version 1.2.
    # This may need to change once this issue is addressed:
    # https://github.com/fog/fog-openstack/issues/197
    hardware.provision_state      = host.provision_state.nil? ? "available" : host.provision_state

    hardware
  end

  def get_extra_attributes(introspection_details)
    return {} if introspection_details.blank? || introspection_details["extra"].nil?
    introspection_details["extra"]
  end

  def process_host_hardware_disks(hardware, extra_attributes)
    return [] if extra_attributes.nil? || (disks = extra_attributes.fetch_path('disk')).blank?
    inventory_disks = []

    disks.keys.delete_if { |x| x.include?('{') || x == 'logical' }.map do |d|
      # Logical index contains number of logical disks
      # TODO(lsmola) For now ignoring smart data, that are in format e.g. sda{cciss,1}, we need to design
      # how to represent RAID
      # Convert the disk size from GB to B
      disk                 = persister.disks.find_or_build_by(:hardware => hardware, :device_name => d)
      disk_size            = disks.fetch_path(d, 'size').to_i * 1_024**3
      disk.device_type     = 'disk'
      disk.controller_type = 'scsi'
      disk.present         = true
      disk.filename        = disks.fetch_path(d, 'id') || disks.fetch_path(d, 'scsi-id')
      disk.location        = d
      disk.size            = disk_size
      disk.disk_type       = nil
      disk.mode            = 'persistent'
      inventory_disks << disk
    end

    inventory_disks
  end

  def clusters_and_host_mapping
    clusters = []
    cluster_host_mapping = {}
    orchestration_stacks = collector.orchestration_stacks
    orchestration_stacks&.each do |stack|
      uid = stack.parent
      next unless uid

      nova_server = stack.resources.detect do |r|
        collector.stack_server_resource_types.include?(r.resource_type)
      end
      next unless nova_server

      host = collector.hosts.find { |h| h.instance_uuid == nova_server.physical_resource_id }
      cluster_host_mapping[host.uuid] = uid

      name = collector.orchestration_stacks.find { |s| s.id == stack.parent }.stack_name
      clusters << {:name => name, :uid => uid}
    end
    return clusters.uniq, cluster_host_mapping
  end

  def find_resource(_uid, _stack_id)
    nil
  end
end

class ManageIQ::Providers::Openstack::Inventory::Parser::InfraManager < ManageIQ::Providers::Openstack::Inventory::Parser
  include Vmdb::Logging

  include ManageIQ::Providers::Openstack::RefreshParserCommon::HelperMethods
  include ManageIQ::Providers::Openstack::RefreshParserCommon::Images
  include ManageIQ::Providers::Openstack::RefreshParserCommon::Objects
  include ManageIQ::Providers::Openstack::RefreshParserCommon::OrchestrationStacks

  def parse
    @ems               = collector.manager
    @data              = {}
    @data_index        = {}
    @resource_to_stack = {}

    @image_service   = collector.image_service
    @storage_service = collector.storage_service

    images
    get_object_store
    hosts
    orchestration_stacks
    clusters
  end

  def images
    collector.images.each { |image| parse_image(image) }
  end

  def hosts
    collector.hosts.each { |host| parse_host(host) }
  end

  def orchestration_stacks
    process_collection(collector.stacks, :orchestration_stacks) { |stack| parse_stack(stack) }
  end

  def clusters
    collector.clusters.each { |cluster| parse_cluster(cluster) }
  end

  private

  def parse_image(image)
    uid      = image.id.to_s
    guest_os = OperatingSystem.normalize_os_name(image.try(:os_distro) || 'unknown')

    persister_image = persister.miq_templates.build(
      :uid_ems            => uid,
      :ems_ref            => uid,
      :name               => image.name.presence || uid,
      :vendor             => "openstack",
      :raw_power_state    => "never",
      :location           => "unknown",
      :template           => true,
      :publicly_available => public?(image)
    )

    persister.operating_systems.build(
      :vm_or_template => persister_image,
      :product_name   => guest_os,
      :distribution   => image.try(:os_distro),
      :version        => image.try(:os_version)
    )

    persister.hardwares.build(
      :vm_or_template      => persister_image,
      :guest_os            => guest_os,
      :bitness             => architecture(image),
      :disk_size_minimum   => (image.min_disk * 1.gigabyte),
      :memory_mb_minimum   => image.min_ram,
      :root_device_type    => image.disk_format,
      :size_on_disk        => image.size,
      :virtualization_type => image.properties.try(:[], 'hypervisor_type') || image.attributes['hypervisor_type']
    )
  end

  def get_extra_attributes(introspection_details)
    return {} if introspection_details.blank? || introspection_details["extra"].nil?

    introspection_details["extra"]
  end

  def parse_host(host)
    uid                 = host.uuid
    host_name           = identify_host_name(host.instance_uuid, uid)
    hypervisor_hostname = identify_hypervisor_hostname(host)
    ip_address          = identify_primary_ip_address(host)
    hostname            = ip_address

    introspection_details = collector.introspection_details(host)
    extra_attributes      = get_extra_attributes(introspection_details)

    # Get the cloud_host_attributes by hypervisor hostname, only compute hosts can get this
    cloud_host_attributes = collector.cloud_host_attributes_by_host[hypervisor_hostname.downcase]&.first

    cluster_ref = collector.cluster_by_host[host.instance_uuid]
    ems_cluster = persister.clusters.lazy_find(cluster_ref) if cluster_ref

    new_result = {
      :name                 => host_name,
      :uid_ems              => host.instance_uuid,
      :ems_ref              => uid,
      :vmm_vendor           => 'redhat',
      :vmm_product          => identify_product(host.instance_uuid),
      # Can't get this from ironic, maybe from Glance metadata, when it will be there, or image fleecing?
      :vmm_version          => nil,
      :ipaddress            => ip_address,
      :hostname             => hostname,
      :mac_address          => identify_primary_mac_address(host),
      :ipmi_address         => identify_ipmi_address(host),
      :power_state          => lookup_power_state(host.power_state),
      :connection_state     => lookup_connection_state(host.power_state),
      :maintenance          => host.maintenance,
      :maintenance_reason   => host.maintenance_reason,
      :hypervisor_hostname  => hypervisor_hostname,
      :service_tag          => extra_attributes.fetch_path('system', 'product', 'serial'),
      # TODO(lsmola) need to add column for connection to SecurityGroup
      # :security_group_id  => security_group_id
      # Attributes taken from the Cloud provider
      :availability_zone_id => cloud_host_attributes.try(:[], :availability_zone_id),
      :ems_cluster          => ems_cluster
    }

    persister_host = persister.hosts.build(new_result)

    persister.host_operating_systems.build(:host => persister_host, :product_name => "linux")

    hardware = persister.host_hardwares.build(parse_host_hardware(host, introspection_details).merge(:host => persister_host))
    parse_host_disks(extra_attributes).each { |disk| persister.host_disks.build(disk.merge(:hardware => hardware)) }

    return uid, new_result
  end

  def parse_host_hardware(host, introspection_details)
    extra_attributes     = get_extra_attributes(introspection_details)
    cpu_sockets          = extra_attributes.fetch_path('cpu', 'physical', 'number').to_i
    cpu_total_cores      = extra_attributes.fetch_path('cpu', 'logical', 'number').to_i
    cpu_cores_per_socket = cpu_sockets > 0 ? cpu_total_cores / cpu_sockets : 0
    cpu_speed            = introspection_details.fetch_path('inventory', 'cpu', 'frequency').to_i

    {
      :memory_mb            => host.properties['memory_mb'],
      :disk_capacity        => host.properties['local_gb'],
      :cpu_total_cores      => cpu_total_cores,
      :cpu_sockets          => cpu_sockets,
      :cpu_cores_per_socket => cpu_cores_per_socket,
      :cpu_speed            => cpu_speed,
      :cpu_type             => extra_attributes.fetch_path('cpu', 'physical_0', 'version'),
      :manufacturer         => extra_attributes.fetch_path('system', 'product', 'vendor'),
      :model                => extra_attributes.fetch_path('system', 'product', 'name'),
      :number_of_nics       => extra_attributes.fetch_path('network').try(:keys).try(:count).to_i,
      :bios                 => extra_attributes.fetch_path('firmware', 'bios', 'version'),
      # Can't get these 2 from ironic, maybe from Glance metadata, when it will be there, or image fleecing?
      :guest_os_full_name   => nil,
      :guest_os             => nil,
      :introspected         => introspection_details.present?,
      # fog-openstack baremetal service defaults to Ironic API v1.1.
      # In version 1.1 "available" is shown as null in JSON. It is correctly
      # shown as "available" starting with version 1.2.
      # This may need to change once this issue is addressed:
      # https://github.com/fog/fog-openstack/issues/197
      :provision_state      => host.provision_state.nil? ? "available" : host.provision_state,
    }
  end

  def parse_host_disks(extra_attributes)
    return [] if extra_attributes.nil? || (disks = extra_attributes.fetch_path('disk')).blank?

    disks.keys.delete_if { |x| x.include?('{') || x == 'logical' }.map do |disk|
      # Logical index contains number of logical disks
      # TODO(lsmola) For now ignoring smart data, that are in format e.g. sda{cciss,1}, we need to design
      # how to represent RAID
      # Convert the disk size from GB to B
      disk_size = disks.fetch_path(disk, 'size').to_i * 1_024**3
      {
        :device_name     => disk,
        :device_type     => 'disk',
        :controller_type => 'scsi',
        :present         => true,
        :filename        => disks.fetch_path(disk, 'id') || disks.fetch_path(disk, 'scsi-id'),
        :location        => disk,
        :size            => disk_size,
        :disk_type       => nil,
        :mode            => 'persistent'
      }
    end
  end

  def parse_cluster(cluster)
    persister.clusters.build(
      :ems_ref => cluster[:uid],
      :uid_ems => cluster[:uid],
      :name    => cluster[:name]
    )
  end

  def parse_stack(stack)
    uid = stack.id.to_s

    resources  = find_stack_resources(stack)
    outputs    = find_stack_outputs(stack)
    parameters = find_stack_parameters(stack)
    template   = find_stack_template(stack)

    new_result = {
      :ems_ref                => uid,
      :name                   => stack.stack_name,
      :description            => stack.description,
      :status                 => stack.stack_status,
      :status_reason          => stack.stack_status_reason,
      :parent                 => persister.orchestration_stacks.lazy_find(stack.parent),
      :resources              => resources,
      :orchestration_template => persister.orchestration_templates.lazy_find(template[:ems_ref]),
    }

    persister_stack = persister.orchestration_stacks.build(
      new_result.except(:parent_stack_id, :resources, :outputs, :parameters)
    )

    resources.each do |res|
      res[:stack] = persister_stack
      persister.orchestration_stacks_resources.build(res)
    end

    outputs.each do |output|
      output[:stack] = persister_stack
      persister.orchestration_stacks_outputs.build(output)
    end

    parameters.each do |param|
      param[:stack] = persister_stack
      persister.orchestration_stacks_parameters.build(param)
    end

    return uid, new_result
  end

  def parse_stack_template(stack)
    uid = stack.id
    template = stack.template

    new_result = {
      :name        => stack.stack_name,
      :ems_ref     => uid,
      :description => template.description,
      :content     => template.content,
      :orderable   => false
    }

    persister.orchestration_templates.build(new_result)

    return uid, new_result
  end

  def server_address(server, key)
    # TODO(lsmola) Nova is missing information which address is primary now,
    # so just taking first. We need to figure out how to identify it if
    # there are multiple.
    server&.addresses&.fetch_path('ctlplane', 0, key)
  end

  def identify_product(instance_uuid)
    purpose = collector.server_purpose_by_instance_uuid[instance_uuid]
    return nil unless purpose

    if purpose == 'NovaCompute'
      'rhel (Nova Compute hypervisor)'
    else
      "rhel (No hypervisor, Host Type is #{purpose})"
    end
  end

  def identify_host_name(instance_uuid, uid)
    purpose = collector.server_purpose_by_instance_uuid[instance_uuid]
    return uid unless purpose

    "#{uid} (#{purpose})"
  end

  def identify_primary_mac_address(host)
    server = collector.servers_by_id[host.instance_uuid]
    server_address(server, 'OS-EXT-IPS-MAC:mac_addr')
  end

  def identify_primary_ip_address(host)
    server = collector.servers_by_id[host.instance_uuid]
    server_address(server, 'addr')
  end

  def identify_ipmi_address(host)
    host.driver_info["ipmi_address"]
  end

  def identify_hypervisor_hostname(host)
    collector.servers_by_id[host.instance_uuid]&.name
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

  def get_object_content(obj)
    obj.body
  end

  #
  # Helper methods
  #

  def process_collection(collection, key)
    @data[key] ||= []
    return if collection.nil?

    collection.each do |item|
      uid, new_result = yield(item)

      @data[key] << new_result
      @data_index.store_path(key, uid, new_result)
    end
  end
end

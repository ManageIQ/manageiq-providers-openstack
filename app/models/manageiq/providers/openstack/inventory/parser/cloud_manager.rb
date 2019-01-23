class ManageIQ::Providers::Openstack::Inventory::Parser::CloudManager < ManageIQ::Providers::Openstack::Inventory::Parser
  include ManageIQ::Providers::Openstack::RefreshParserCommon::HelperMethods
  include ManageIQ::Providers::Openstack::RefreshParserCommon::Images
  include ManageIQ::Providers::Openstack::Inventory::Parser::CommonMethods

  def parse
    availability_zones
    cloud_services
    flavors
    miq_templates("ManageIQ::Providers::Openstack::CloudManager::Template")
    key_pairs
    orchestration_stacks("ManageIQ::Providers::Openstack::CloudManager::OrchestrationStack")
    quotas
    vms
    cloud_tenants
    vnfs
    vnfds
    host_aggregates
    volume_templates
    volume_snapshot_templates
  end

  def volume_templates
    collector.volume_templates.each do |vt|
      next if vt.attributes["bootable"].to_s != "true"
      volume_template = persister.miq_templates.find_or_build(vt.id)
      volume_template.type = "ManageIQ::Providers::Openstack::CloudManager::VolumeTemplate"
      volume_template.name = vt.name.blank? ? vt.id : vt.name
      volume_template.cloud_tenant = persister.cloud_tenants.lazy_find(vt.tenant_id) if vt.tenant_id
      volume_template.location = "N/A"
      volume_template.vendor = "openstack"
    end
  end

  def volume_snapshot_templates
    collector.volume_snapshot_templates.each do |vt|
      # next if vt["attributes"].["bootable"].to_s != "true"
      volume_template = persister.miq_templates.find_or_build(vt["id"])
      volume_template.type = "ManageIQ::Providers::Openstack::CloudManager::VolumeSnapshotTemplate"
      volume_template.name = (vt['display_name'] || vt['name']).blank? ? vt.id : (vt['display_name'] || vt['name'])
      volume_template.cloud_tenant = persister.cloud_tenants.lazy_find(vt["os-extended-snapshot-attributes:project_id"])
      volume_template.location = "N/A"
      volume_template.vendor = "openstack"
    end
  end

  def availability_zones
    collector.availability_zones.each do |az|
      availability_zone = persister.availability_zones.find_or_build(az.zoneName)
      availability_zone.ems_ref = az.zoneName
      availability_zone.name = az.zoneName
    end
    # ensure the null az exists
    null_az = persister.availability_zones.find_or_build("null_az")
    null_az.type = "ManageIQ::Providers::Openstack::CloudManager::AvailabilityZoneNull"
    null_az.ems_ref = "null_az"
  end

  def cloud_services
    related_infra_ems = collector.manager.provider.try(:infra_ems)
    hosts = related_infra_ems.try(:hosts)

    collector.cloud_services.each do |s|
      host = hosts.try(:find) { |h| h.hypervisor_hostname == s.host.split('.').first }
      system_services = host.try(:system_services)
      system_service = system_services.try(:find) { |ss| ss.name =~ /#{s.binary}/ }

      cloud_service = persister.cloud_services.find_or_build(s.id)
      cloud_service.ems_ref = s.id
      cloud_service.source = 'compute'
      cloud_service.executable_name = s.binary
      cloud_service.hostname = s.host
      cloud_service.status = s.state
      cloud_service.scheduling_disabled = s.status == 'disabled'
      cloud_service.scheduling_disabled_reason = s.disabled_reason
      cloud_service.host = host
      cloud_service.system_service = system_service
      cloud_service.availability_zone = persister.availability_zones.lazy_find(s.zone)
    end
  end

  def flavors
    collector.flavors.each do |f|
      make_flavor(f)
    end
  end

  def make_flavor(f)
    flavor = persister.flavors.find_or_build(f.id)
    flavor.name = f.name
    flavor.enabled = !f.disabled
    flavor.cpus = f.vcpus
    flavor.memory = f.ram.megabytes
    flavor.publicly_available = f.is_public
    flavor.root_disk_size = f.disk.to_i.gigabytes
    flavor.swap_disk_size = f.swap.to_i.megabytes
    flavor.ephemeral_disk_size = f.ephemeral.nil? ? nil : f.ephemeral.to_i.gigabytes
    flavor.ephemeral_disk_count = if f.ephemeral.nil?
                                    nil
                                  elsif f.ephemeral.to_i > 0
                                    1
                                  else
                                    0
                                  end
    flavor.cloud_tenants = if f.is_public
                             # public flavors are associated with every tenant
                             collector.tenants.map { |tenant| persister.cloud_tenants.lazy_find(tenant.id) }
                           else
                             # Add tenants with access to the private flavor
                             collector.tenant_ids_with_flavor_access(f.id).map { |tenant_id| persister.cloud_tenants.lazy_find(tenant_id) }
                           end
  end

  def host_aggregates
    collector.host_aggregates.each do |ha|
      related_infra_ems = collector.manager.provider.try(:infra_ems)
      ems_hosts = related_infra_ems.try(:hosts)
      hosts = ha.hosts.map do |fog_host|
        ems_hosts.try(:find) { |h| h.hypervisor_hostname == fog_host.split('.').first }
      end
      host_aggregate = persister.host_aggregates.find_or_build(ha.id)
      host_aggregate.ems_ref = ha.id.to_s
      host_aggregate.name = ha.name
      host_aggregate.metadata = ha.metadata
      host_aggregate.hosts = hosts.compact.uniq
    end
  end

  def key_pairs
    collector.key_pairs.each do |kp|
      key_pair = persister.key_pairs.find_or_build(kp.name)
      key_pair.name = kp.name
      key_pair.fingerprint = kp.fingerprint
    end
  end

  def quotas
    collector.quotas.each do |q|
      # Metadata items, injected files, server groups, and rbac policies are not modeled,
      # Skip them for now.
      q.except("id", "tenant_id", "service_name", "metadata_items", "injected_file_content_bytes",
               "injected_files", "injected_file_path_bytes", "server_groups", "server_group_members",
               "rbac_policy").collect do |key, value|
        begin
          value = value.to_i
        rescue
          value = 0
        end
        id = q["id"] || q["tenant_id"]
        uid = [id, key]
        quota = persister.cloud_resource_quotas.find_or_build(uid)
        quota.service_name = q["service_name"]
        quota.ems_ref = uid
        quota.name = key
        quota.value = value
        quota.cloud_tenant = persister.cloud_tenants.lazy_find(q["tenant_id"])
      end
    end
  end

  def vms
    related_infra_ems = collector.manager.provider.try(:infra_ems)
    hosts = related_infra_ems.try(:hosts)

    collector.vms.each do |s|
      if hosts && !s.os_ext_srv_attr_host.blank?
        parent_host = hosts.find_by('lower(hypervisor_hostname) = ? OR lower(hypervisor_hostname) = ?', s.os_ext_srv_attr_host.split('.').first.downcase, s.os_ext_srv_attr_host.downcase)
        parent_cluster = parent_host.try(:ems_cluster)
      else
        parent_host = nil
        parent_cluster = nil
      end

      availability_zone = s.availability_zone.blank? ? "null_az" : s.availability_zone
      miq_template_lazy = persister.miq_templates.lazy_find(s.image["id"])

      server = persister.vms.find_or_build(s.id.to_s)
      server.uid_ems = s.id
      server.name = s.name
      server.vendor = "openstack"
      server.raw_power_state = s.state || "UNKNOWN"
      server.connection_state = "connected"
      server.location = "unknown"
      server.host = parent_host
      server.ems_cluster = parent_cluster
      server.availability_zone = persister.availability_zones.lazy_find(availability_zone)
      server.key_pairs = [persister.key_pairs.lazy_find(s.key_name)].compact
      server.cloud_tenant = persister.cloud_tenants.lazy_find(s.tenant_id.to_s)
      server.genealogy_parent = miq_template_lazy unless s.image["id"].nil?

      # to populate the hardware, we need some fields from the flavor object
      # that we don't already have from the flavor field on the server details
      # returned from the openstack api. It's possible that no such flavor was found
      # due to some intermittent network issue or etc, so we use try to not break.
      flavor = collector.find_flavor(s.flavor["id"].to_s)
      make_flavor(flavor) unless flavor.nil?
      server.flavor = persister.flavors.lazy_find(s.flavor["id"].to_s)

      hardware = persister.hardwares.find_or_build(server)
      hardware.vm_or_template = server
      hardware.cpu_sockets = flavor.try(:vcpus)
      hardware.cpu_cores_per_socket = 1
      hardware.cpu_total_cores = flavor.try(:vcpus)
      hardware.cpu_speed = parent_host.try(:hardware).try(:cpu_speed)
      hardware.memory_mb = flavor.try(:ram)
      hardware.disk_capacity = (
        flavor.try(:disk).to_i.gigabytes + flavor.try(:swap).to_i.megabytes + flavor.try(:ephemeral).to_i.gigabytes
      )
      hardware.guest_os = persister.hardwares.lazy_find(miq_template_lazy, :key => :guest_os)

      operating_system = persister.operating_systems.find_or_build(server)
      operating_system.vm_or_template = server
      operating_system.product_name = persister.operating_systems.lazy_find(miq_template_lazy, :key => :product_name)
      operating_system.distribution = persister.operating_systems.lazy_find(miq_template_lazy, :key => :distribution)
      operating_system.version = persister.operating_systems.lazy_find(miq_template_lazy, :key => :version)

      attachment_names = {'vda' => 'Root disk'}
      disk_location = "vda"
      if (root_size = flavor.try(:disk).to_i.gigabytes).zero?
        root_size = 1.gigabytes
      end
      make_instance_disk(hardware, root_size, disk_location.dup, attachment_names[disk_location])
      ephemeral_size = flavor.try(:ephemeral).to_i.gigabytes
      unless ephemeral_size.zero?
        disk_location = "vdb"
        attachment_names[disk_location] = "Ephemeral disk"
        make_instance_disk(hardware, ephemeral_size, disk_location, attachment_names[disk_location])
      end
      swap_size = flavor.try(:swap).to_i.megabytes
      unless swap_size.zero?
        disk_location = disk_location.succ
        attachment_names[disk_location] = "Swap disk"
        make_instance_disk(hardware, swap_size, disk_location, attachment_names[disk_location])
      end

      # Make disks in the inventory for each of this server's volume attachments.
      # Start by checking the raw attributes from fog to see whether whether this
      # server has any attachments. If it does, then use the fog object's
      # volume_attachments method to inflate them and get the device names.
      # Checking the attribute first avoids making an expensive api call for
      # every server when they may not all have attachments.
      # Don't worry about filling in the volume, since the volume service refresh
      # will take care of that.
      if s.attributes.fetch("os-extended-volumes:volumes_attached", []).length > 0
        s.volume_attachments.each do |attachment|
          dev = File.basename(attachment['device'])
          persister.disks.find_or_build_by(
            :hardware    => hardware,
            # reuse the device names from above in the event that this is an
            # instance that was booted from a volume
            :device_name => attachment_names.fetch(dev, dev)
          ).assign_attributes(
            :location        => dev,
            :device_type     => "disk",
            :controller_type => "openstack"
          )
        end
      end
      vm_and_template_labels(server, s.metadata || [])
      vm_and_template_taggings(server, map_labels("VmOpenstack", s.metadata || []))
    end
  end

  def vm_and_template_labels(resource, tags)
    tags.each do |tag|
      persister.vm_and_template_labels.find_or_build_by(:resource => resource, :name => tag.key).assign_attributes(
        :section => 'labels',
        :value   => tag.value,
        :source  => 'openstack'
      )
    end
  end

  # Returns array of InventoryObject<Tag>.
  def map_labels(model_name, labels)
    label_hashes = labels.collect do |label|
      {:name => label.key, :value => label.value}
    end
    persister.tag_mapper.map_labels(model_name, label_hashes)
  end

  def vm_and_template_taggings(resource, tags_inventory_objects)
    tags_inventory_objects.each do |tag|
      persister.vm_and_template_taggings.build(:taggable => resource, :tag => tag)
    end
  end

  def vnfs
    collector.vnfs.each do |v|
      vnf = persister.orchestration_stacks.find_or_build(v.id)
      vnf.type = "ManageIQ::Providers::Openstack::CloudManager::Vnf"
      vnf.name = v.name
      vnf.description = v.description
      vnf.status = v.status
      vnf.cloud_tenant = persister.cloud_tenants.lazy_find(v.tenant_id)

      output = persister.orchestration_stacks_outputs.find_or_build("#{v.id}mgmt_url")
      output.key = 'mgmt_url'
      output.value = v.mgmt_url
      output.stack = vnf
    end
  end

  def vnfds
    collector.vnfds.each do |v|
      vnfd = persister.orchestration_templates.find_or_build(v.id)
      vnfd.type = "ManageIQ::Providers::Openstack::CloudManager::VnfdTemplate"
      vnfd.name = v.name.blank? ? v.id : v.name
      vnfd.description = v.description
      vnfd.content = v.vnf_attributes["vnfd"]
      vnfd.orderable = true
    end
  end

  def make_instance_disk(hardware, size, location, name)
    disk = persister.disks.find_or_build_by(
      :hardware    => hardware,
      :device_name => name
    ).assign_attributes(
      :location        => location,
      :size            => size,
      :device_type     => "disk",
      :controller_type => "openstack"
    )
    disk
  end

  def find_resource(uid, stack_id)
    # in some cases, a stack resource may refer to a physical resource
    # that doesn't exist. check that the physical resource actually exists
    # so that find_or_build doesn't produce an "empty" vm.
    if collector.vms_by_id.key?(uid)
      s = persister.vms.find_or_build(uid)
      s.orchestration_stack = persister.orchestration_stacks.lazy_find(stack_id)
    end
  end
end

module ManageIQ::Providers::Openstack::Inventory::Parser::CommonMethods
  def miq_templates(type)
    collector.images.each do |i|
      parent_server_uid = parse_image_parent_id(i)
      image = persister.miq_templates.find_or_build(i.id)
      image.type = type
      image.uid_ems = i.id
      image.name = i.name.presence || i.id.to_s
      image.vendor = "openstack"
      image.raw_power_state = "never"
      image.template = true
      image.publicly_available = public_image?(i)
      image.cloud_tenants = image_tenants(i)
      image.location = "unknown"
      image.cloud_tenant = persister.cloud_tenants.lazy_find(i.owner) if i.owner
      image.genealogy_parent = persister.vms.lazy_find(parent_server_uid) unless parent_server_uid.nil?

      guest_os = OperatingSystem.normalize_os_name(i.try(:os_distro) || 'unknown')

      hardware = persister.hardwares.find_or_build(image)
      hardware.vm_or_template = image
      hardware.guest_os = guest_os
      hardware.bitness = image_architecture(i)
      hardware.disk_size_minimum = (i.min_disk * 1.gigabyte)
      hardware.memory_mb_minimum = i.min_ram
      hardware.root_device_type = i.disk_format
      hardware.size_on_disk = i.size
      hardware.virtualization_type = i.properties.try(:[], 'hypervisor_type') || i.attributes['hypervisor_type']

      operating_system = persister.operating_systems.find_or_build(image)
      operating_system.vm_or_template = image
      operating_system.product_name = guest_os
      operating_system.distribution = i.try(:os_distro)
      operating_system.version = i.try(:os_version)
    end
  end

  def orchestration_stacks(type)
    collector.orchestration_stacks.each do |stack|
      o = persister.orchestration_stacks.find_or_build(stack.id.to_s)
      o.type = type
      o.name = stack.stack_name
      o.description = stack.description
      o.status = stack.stack_status
      o.status_reason = stack.stack_status_reason
      o.parent = persister.orchestration_stacks.lazy_find(stack.parent)
      o.orchestration_template = orchestration_template(stack, type)
      o.cloud_tenant = persister.cloud_tenants.lazy_find(stack.service.current_tenant["id"])
      orchestration_stack_resources(stack, o)
      orchestration_stack_outputs(stack, o)
      orchestration_stack_parameters(stack, o)
    end
  end

  def orchestration_template(stack, type)
    template = collector.orchestration_template(stack)
    if template
      o = persister.orchestration_templates.find_or_build(stack.id)
      o.type = type
      o.name = stack.stack_name
      o.description = stack.template.description
      o.content = stack.template.content
      o.orderable = false
      o
    end
  end

  def orchestration_stack_resources(stack, stack_inventory_object)
    raw_resources = collector.orchestration_resources(stack)
    # reject resources that don't have a physical resource id, because that
    # means they failedq to be successfully created
    raw_resources.reject! { |r| r.physical_resource_id.blank? }
    raw_resources.each do |resource|
      uid = resource.physical_resource_id
      o = persister.orchestration_stacks_resources.find_or_build(uid)
      o.ems_ref = uid
      o.logical_resource = resource.logical_resource_id
      o.physical_resource = resource.physical_resource_id
      o.resource_category = resource.resource_type
      o.resource_status = resource.resource_status
      o.resource_status_reason = resource.resource_status_reason
      o.last_updated = resource.updated_time
      o.stack = stack_inventory_object
      find_resource(uid, stack.id)
    end
  end

  def orchestration_stack_parameters(stack, stack_inventory_object)
    collector.orchestration_parameters(stack).each do |param_key, param_val|
      uid = compose_ems_ref(stack.id, param_key)
      o = persister.orchestration_stacks_parameters.find_or_build(uid)
      o.ems_ref = uid
      o.name = param_key
      o.value = param_val
      o.stack = stack_inventory_object
    end
  end

  def orchestration_stack_outputs(stack, stack_inventory_object)
    collector.orchestration_outputs(stack).each do |output|
      uid = compose_ems_ref(stack.id, output['output_key'])
      o = persister.orchestration_stacks_outputs.find_or_build(uid)
      o.ems_ref = uid
      o.key = output['output_key']
      o.value = output['output_value']
      o.description = output['description']
      o.stack = stack_inventory_object
    end
  end

  def cloud_tenants
    collector.tenants.each do |t|
      tenant = persister.cloud_tenants.find_or_build(t.id)
      tenant.name = t.name
      tenant.description = t.description
      tenant.enabled = t.enabled
      tenant.ems_ref = t.id
      tenant.parent = if t.try(:parent_id).blank?
                        nil
                      else
                        persister.cloud_tenants.lazy_find(t.try(:parent_id))
                      end
    end
  end

  # Compose an ems_ref combining some existing keys
  def compose_ems_ref(*keys)
    keys.join('_')
  end

  # Identify whether the given image is publicly available
  def public_image?(image)
    # Glance v1
    return image.is_public if image.respond_to?(:is_public)
    # Glance v2
    image.visibility != 'private' if image.respond_to?(:visibility)
  end

  # Identify whether the given image has a 32 or 64 bit architecture
  def image_architecture(image)
    architecture = image.properties.try(:[], 'architecture') || image.attributes['architecture']
    return nil if architecture.blank?
    # Just simple name to bits, x86_64 will be the most used, we should probably support displaying of
    # architecture name
    architecture.include?("64") ? 64 : 32
  end

  # Identify the id of the parent of this image.
  def parse_image_parent_id(image)
    if collector.image_service.name == :glance
      # What version of openstack is this glance v1 on some old openstack version?
      return image.copy_from["id"] if image.respond_to?(:copy_from) && image.copy_from
      # Glance V2
      return image.instance_uuid if image.respond_to?(:instance_uuid)
      # Glance V1
      image.properties.try(:[], 'instance_uuid')
    elsif image.server
      # Probably nova images?
      image.server["id"]
    end
  end

  def image_tenants(image)
    tenants = []
    if public_image?(image)
      # For public image we will fill a relation to all tenants,
      # since calling the members api for a public image throws a 403.
      collector.tenants.each do |t|
        tenants << persister.cloud_tenants.lazy_find(t.id)
      end
    else
      # Add owner of the image
      tenants << persister.cloud_tenants.lazy_find(image.owner) if image.owner
      # TODO: Glance v2 doesn't support members for "private" images, implement `members` for "shared" images later
      if image.respond_to?(:is_public) && (members = image.members).any?
        tenants += members.map { |x| persister.cloud_tenants.lazy_find(x['member_id']) }
      end
    end
    tenants
  end
end

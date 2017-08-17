class ManageIQ::Providers::Openstack::Inventory::Collector::TargetCollection < ManageIQ::Providers::Openstack::Inventory::Collector
  include ManageIQ::Providers::Openstack::Inventory::Collector::HelperMethods

  def initialize(_manager, _target)
    super
    parse_targets!
    infer_related_ems_refs!

    # Reset the target cache, so we can access new targets inside
    target.manager_refs_by_association_reset
  end

  def references(collection)
    target.manager_refs_by_association.try(:[], collection).try(:[], :ems_ref).try(:to_a) || []
  end

  def name_references(collection)
    target.manager_refs_by_association.try(:[], collection).try(:[], :name).try(:to_a) || []
  end

  def availability_zones
    return [] if references(:availability_zones).blank?
    @availability_zones = references(:availability_zones).collect do |az|
      OpenStruct.new(:zoneName => az)
    end
  end

  def cloud_networks
    return [] if references(:cloud_networks).blank?
    @cloud_networks = references(:cloud_networks).collect do |network_id|
      safe_get { network_service.networks.get(network_id) }
    end.compact
  end

  def network_ports
    return [] if references(:network_ports).blank?
    @network_ports = references(:network_ports).collect do |port_id|
      safe_get { network_service.ports.get(port_id) }
    end.compact
  end

  def network_routers
    return [] if references(:network_routers).blank?
    @network_routers = references(:network_routers).collect do |router_id|
      safe_get { network_service.routers.get(router_id) }
    end.compact
  end

  def security_groups
    return [] if references(:security_groups).blank?
    @security_groups = references(:security_groups).collect do |security_group_id|
      safe_get { network_service.security_groups.get(security_group_id) }
    end.compact
  end

  def floating_ips
    return [] if references(:floating_ips).blank?
    @floating_ips = references(:floating_ips).collect do |floating_ip_id|
      safe_get { network_service.floating_ips.get(floating_ip_id) }
    end.compact
  end

  def orchestration_stacks
    return [] if references(:orchestration_stacks).blank?
    @orchestration_stacks = references(:orchestration_stacks).collect do |stack_id|
      safe_get { orchestration_service.stacks.get(stack_id) }
    end.compact
  end

  def vms
    return [] if references(:vms).blank?
    return @vms if @vms.any?
    @vms = references(:vms).collect do |vm_id|
      safe_get { compute_service.servers.get(vm_id) }
    end.compact
  end

  def flavors
    return [] if references(:flavors).blank?
    @flavors = references(:flavors).collect do |flavor_id|
      safe_get { compute_service.flavors.get(flavor_id) }
    end.compact
  end

  def images
    return [] if references(:images).blank?
    @images = references(:images).collect do |image_id|
      safe_get { image_service.images.get(image_id) }
    end.compact
  end

  def tenants
    return [] if references(:cloud_tenants).blank?
    @cloud_tenants = references(:cloud_tenants).collect do |cloud_tenant_id|
      safe_get { identity_service.tenants.find_by_id(cloud_tenant_id) }
    end.compact
  end

  def key_pairs
    return [] if references(:key_pairs).blank?
    @key_pairs = references(:key_pairs).collect do |key_pair_id|
      safe_get { compute_service.key_pairs.get(key_pair_id) }
    end.compact
  end

  def flavors_by_id
    @flavors_by_id ||= {}
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

  def orchestration_resources(stack)
    @os_handle ||= manager.openstack_handle
    safe_list { stack.resources }
  end

  private

  def parse_targets!
    target.targets.each do |t|
      case t
      when Vm
        parse_vm_target!(t)
      end
    end
  end

  def parse_vm_target!(t)
    add_simple_target!(:vms, t.ems_ref)
  end

  def add_simple_target!(association, ems_ref)
    return if ems_ref.blank?

    target.add_target(:association => association, :manager_ref => {:ems_ref => ems_ref})
  end

  def infer_related_ems_refs!
    # We have a list of instances_refs collected from events. Now we want to look into our DB and API, and collect
    # ems_refs of every related object. Now this is not very nice fro ma design point of view, but we really want
    # to see changes in VM's associated objects, so the VM view is always consistent and have fresh data.
    unless references(:vms).blank?
      infer_related_vm_ems_refs_db!
      infer_related_vm_ems_refs_api!
    end
  end

  def infer_related_vm_ems_refs_db!
    changed_vms = manager.vms.where(:ems_ref => references(:vms)).includes(:key_pairs, :network_ports, :floating_ips,
                                                                           :orchestration_stack, :cloud_networks, :cloud_tenant, :parent)
    changed_vms.each do |vm|
      stack      = vm.orchestration_stack
      all_stacks = ([stack] + (stack.try(:ancestors) || [])).compact

      all_stacks.collect(&:ems_ref).compact.each { |ems_ref| add_simple_target!(:orchestration_stacks, ems_ref) }
      vm.cloud_networks.collect(&:ems_ref).compact.each { |ems_ref| add_simple_target!(:cloud_networks, ems_ref) }
      vm.floating_ips.collect(&:ems_ref).compact.each { |_address| add_simple_target!(:floating_ips, ems_ref) }
      vm.network_ports.collect(&:ems_ref).compact.each do |ems_ref|
        add_simple_target!(:network_ports, ems_ref)
      end
      vm.key_pairs.collect(&:name).compact.each do |name|
        add_simple_target!(:key_pairs, name)
      end
      add_simple_target!(:images, vm.parent.ems_ref) if vm.parent
      add_simple_target!(:cloud_tenants, vm.cloud_tenant.ems_ref) if vm.cloud_tenant
    end
  end

  def infer_related_vm_ems_refs_api!
    vms.each do |vm|
      add_simple_target!(:images, vm.image["id"])
      add_simple_target!(:availability_zones, vm.availability_zone)
      add_simple_target!(:key_pairs, vm.key_name) if vm.key_name
      add_simple_target!(:cloud_tenants, vm.tenant_id)
      add_simple_target!(:flavors, vm.flavor["id"])

      vm.os_interfaces.each do |iface|
        add_simple_target!(:network_ports, iface.port_id)
        add_simple_target!(:cloud_networks, iface.net_id)
      end
      vm.security_groups.each do |sg|
        add_simple_target!(:security_groups, sg.id)
      end
    end
  end
end

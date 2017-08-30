class ManageIQ::Providers::Openstack::Inventory::Collector::TargetCollection < ManageIQ::Providers::Openstack::Inventory::Collector
  include ManageIQ::Providers::Openstack::Inventory::Collector::HelperMethods

  def initialize(_manager, _target)
    super
    @os_handle ||= manager.openstack_handle
    parse_targets!
    infer_related_ems_refs!

    # Reset the target cache, so we can access new targets inside
    target.manager_refs_by_association_reset
  end

  def references(collection)
    target.manager_refs_by_association.try(:[], collection).try(:[], :ems_ref).try(:to_a) || []
  end

  def orchestration_stack_references
    @orchestration_stack_references ||= target.targets.select { |x| x.kind_of?(ManagerRefresh::Target) && x.association == :orchestration_stacks }
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
    return @cloud_networks if @cloud_networks.any?
    @cloud_networks = references(:cloud_networks).collect do |network_id|
      safe_get { network_service.networks.get(network_id) }
    end.compact
  end

  def network_ports
    return [] if references(:network_ports).blank?
    return @network_ports if @network_ports.any?
    @network_ports = (references(:network_ports).collect do |port_id|
      safe_get { network_service.ports.get(port_id) }
    end + references(:network_routers).collect do |router_id|
      network_service.handled_list(:ports, :device_id => router_id)
    end.flatten).compact
  end

  def network_routers
    return [] if references(:network_routers).blank?
    return @network_routers if @network_routers.any?
    @network_routers = references(:network_routers).collect do |router_id|
      safe_get { network_service.routers.get(router_id) }
    end.compact
  end

  def security_groups
    return [] if references(:security_groups).blank?
    return @security_groups if @security_groups.any?
    @security_groups = references(:security_groups).collect do |security_group_id|
      safe_get { network_service.security_groups.get(security_group_id) }
    end.compact
  end

  def floating_ips
    return [] if references(:floating_ips).blank?
    return @floating_ips if @floating_ips.any?
    @floating_ips = references(:floating_ips).collect do |floating_ip|
      safe_get { network_service.floating_ips.all(:floating_ip_address => floating_ip).first }
    end.compact
  end

  def orchestration_stacks
    return [] if orchestration_stack_references.blank?
    return @orchestration_stacks if @orchestration_stacks.any?
    @orchestration_stacks = orchestration_stack_references.collect do |target|
      get_orchestration_stack(target.manager_ref[:ems_ref], target.options[:tenant_id])
    end.compact
  rescue Excon::Errors::Forbidden
    # Orchestration service is detected but not open to the user
    $log.warn("Skip collecting stack references during targeted refresh because the user cannot access the orchestration service.")
    []
  end

  def get_orchestration_stack(stack_id, tenant_id)
    tenant = memoized_get_tenant(tenant_id)
    safe_get { @os_handle.detect_orchestration_service(tenant.try(:name)).stacks.get(stack_id) }
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
    return @flavors if @flavors.any?
    @flavors = references(:flavors).collect do |flavor_id|
      safe_get { compute_service.flavors.get(flavor_id) }
    end.compact
  end

  def images
    return [] if references(:images).blank?
    return @images if @images.any?
    @images = references(:images).collect do |image_id|
      safe_get { image_service.images.get(image_id) }
    end.compact
  end

  def tenants
    return [] if references(:cloud_tenants).blank?
    return @tenants if @tenants.any?
    @tenants = references(:cloud_tenants).collect do |cloud_tenant_id|
      memoized_get_tenant(cloud_tenant_id)
    end.compact
  end

  def memoized_get_tenant(tenant_id)
    return nil if tenant_id.blank?
    @tenant_memo ||= Hash.new do |h, key|
      h[key] = safe_get { identity_service.tenants.find_by_id(key) }
    end
    @tenant_memo[tenant_id]
  end

  def key_pairs
    return [] if references(:key_pairs).blank?
    return @key_pairs if @key_pairs.any?
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

  def orchestration_stack_by_resource_id(resource_id)
    @resources ||= {}
    if @resources.empty?
      orchestration_stacks.each do |stack|
        resources = orchestration_resources(stack)
        resources.each do |r|
          @resources[r.physical_resource_id] = r
        end
      end
    end
    @resources[resource_id]
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

  def vms_by_id
    @vms_by_id ||= Hash[vms.collect { |s| [s.id, s] }]
  end

  private

  def parse_targets!
    target.targets.each do |t|
      case t
      when Vm
        add_simple_target!(:vms, t.ems_ref)
      when CloudTenant
        add_simple_target!(:cloud_tenants, t.ems_ref)
      when OrchestrationStack
        add_simple_target!(:orchestration_stacks, t.ems_ref)
      end
    end
  end

  def add_simple_target!(association, ems_ref, options = {})
    return if ems_ref.blank?

    target.add_target(:association => association, :manager_ref => {:ems_ref => ems_ref}, :options => options)
  end

  def infer_related_ems_refs!
    # We have a list of instances_refs collected from events. Now we want to look into our DB and API, and collect
    # ems_refs of every related object. Now this is not very nice fro ma design point of view, but we really want
    # to see changes in VM's associated objects, so the VM view is always consistent and have fresh data.
    unless references(:vms).blank?
      infer_related_vm_ems_refs_db!
      infer_related_vm_ems_refs_api!
    end
    unless references(:cloud_tenants).blank?
      infer_related_cloud_tenant_ems_refs_db!
      infer_related_cloud_tenant_ems_refs_api!
    end
    unless references(:orchestration_stacks).blank?
      infer_related_orchestration_stacks_ems_refs_db!
      infer_related_orchestration_stacks_ems_refs_api!
    end
  end

  def infer_related_orchestration_stacks_ems_refs_db!
    changed_stacks = manager.orchestration_stacks.where(:ems_ref => references(:orchestration_stacks))
    changed_stacks.each do |stack|
      add_simple_target!(:cloud_tenants, stack.cloud_tenant.ems_ref) unless stack.cloud_tenant.nil?
      add_simple_target!(:orchestration_stacks, stack.parent.ems_ref, :tenant_id => stack.parent.cloud_tenant.ems_ref) unless stack.parent.nil?
    end
  end

  def infer_related_orchestration_stacks_ems_refs_api!
    orchestration_stacks.each do |stack|
      add_simple_target!(:orchestration_stacks, stack.parent, :tenant_id => stack.service.current_tenant["id"]) unless stack.parent.blank?
      add_simple_target!(:cloud_tenants, stack.service.current_tenant["id"]) unless stack.service.current_tenant["id"].blank?
    end
  end

  def infer_related_cloud_tenant_ems_refs_db!
    changed_tenants = manager.cloud_tenants.where(:ems_ref => references(:cloud_tenants))
    changed_tenants.each do |tenant|
      add_simple_target!(:cloud_tenants, tenant.parent.ems_ref) unless tenant.parent.nil?
    end
  end

  def infer_related_cloud_tenant_ems_refs_api!
    tenants.each do |tenant|
      add_simple_target(:cloud_tenants, tenant.try(:parent_id)) unless tenant.try(:parent_id).blank?
    end
  end

  def infer_related_vm_ems_refs_db!
    changed_vms = manager.vms.where(:ems_ref => references(:vms)).includes(:key_pairs, :network_ports, :floating_ips,
                                                                           :orchestration_stack, :cloud_networks, :cloud_tenant, :parent)
    changed_vms.each do |vm|
      stack      = vm.orchestration_stack
      all_stacks = ([stack] + (stack.try(:ancestors) || [])).compact

      all_stacks.each { |s| add_simple_target!(:orchestration_stacks, s.ems_ref, :tenant_id => s.cloud_tenant.id) }
      vm.cloud_networks.collect(&:ems_ref).compact.each { |ems_ref| add_simple_target!(:cloud_networks, ems_ref) }
      vm.floating_ips.collect(&:address).compact.each { |address| add_simple_target!(:floating_ips, address) }
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
      add_simple_target!(:floating_ips, vm.public_ip_address) unless vm.public_ip_address.blank?
    end
    target.manager_refs_by_association_reset
    floating_ips.each do |floating_ip|
      add_simple_target!(:network_routers, floating_ip.router_id)
      add_simple_target!(:network_ports, floating_ip.port_id)
      add_simple_target!(:cloud_networks, floating_ip.floating_network_id)
    end
  end
end

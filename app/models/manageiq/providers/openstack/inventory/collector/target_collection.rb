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

  def targets_by_association(association)
    target.targets.select { |x| x.kind_of?(InventoryRefresh::Target) && x.association == association }.uniq { |x| x.manager_ref[:ems_ref] }
  end

  def availability_zones
    availability_zones_compute
  end

  def availability_zones_compute
    return [] if references(:availability_zones).blank?
    @availability_zones_compute = references(:availability_zones)
  end

  def availability_zones_volume
    []
  end

  def cloud_networks
    return [] unless network_service
    return [] if references(:cloud_networks).blank?
    return @cloud_networks if @cloud_networks.any?
    @cloud_networks = references(:cloud_networks).collect do |network_id|
      safe_get do
        network_service.get_network(network_id).body["network"]
      rescue Fog::OpenStack::Network::NotFound
        nil
      end
    end.compact
  end

  def cloud_subnets
    return [] unless network_service
    return @cloud_subnets if @cloud_subnets.any?
    @cloud_subnets = network_service.handled_list(:subnets, {}, openstack_network_admin?)
  end

  def network_ports
    return [] unless network_service
    return [] if references(:network_ports).blank?
    return @network_ports if @network_ports.any?
    @network_ports = (references(:network_ports).collect do |port_id|
      safe_get { network_service.ports.get(port_id) }
    end + references(:network_routers).collect do |router_id|
      network_service.handled_list(:ports, :device_id => router_id)
    end.flatten).compact
  end

  def network_routers
    return [] unless network_service
    return [] if references(:network_routers).blank?
    return @network_routers if @network_routers.any?
    @network_routers = references(:network_routers).collect do |router_id|
      safe_get { network_service.routers.get(router_id) }
    end.compact
  end

  def security_groups
    return [] unless network_service
    return [] if references(:security_groups).blank?
    return @security_groups if @security_groups.any?
    @security_groups = network_service.handled_list(:security_groups, {}, openstack_network_admin?)
  end

  def firewall_rules
    return [] unless network_service
    return [] if references(:firewall_rules).blank?
    return @firewall_rules if @firewall_rules.any?

    @firewall_rules = network_service.handled_list(:security_group_rules, {}, openstack_network_admin?)
  end

  def floating_ips
    return [] unless network_service
    return [] if references(:floating_ips).blank? && references(:floating_ips_by_address).blank?
    return @floating_ips if @floating_ips.any?
    @floating_ips = references(:floating_ips_by_address).collect do |floating_ip|
      safe_get { network_service.floating_ips.all(:floating_ip_address => floating_ip).first }
    end.compact + references(:floating_ips).collect do |floating_ip_id|
      safe_get { network_service.floating_ips.get(floating_ip_id) }
    end.compact
  end

  def orchestration_stacks
    return [] unless orchestration_service
    return [] if targets_by_association(:orchestration_stacks).blank?
    # Cache of this call is done on individual API results, because we call this method multiple times while chenging
    # the targets_by_association(:orchestration_stacks). The list of targets grows after scanning.
    targets_by_association(:orchestration_stacks).collect do |target|
      get_orchestration_stack(target.manager_ref[:ems_ref], target.options[:tenant_id])
    end.compact
  rescue Excon::Errors::Forbidden
    # Orchestration service is detected but not open to the user
    $log.warn("Skip collecting stack references during targeted refresh because the user cannot access the orchestration service.")
    []
  end

  def get_orchestration_stack(stack_id, _tenant_id = nil)
    # TODO: fog needs to implement /v1/{tenant_id}/stacks/{stack_identity} call, right now the only supported call
    # excepts get(name, id). And when we do just get(id) it degrades to fetching all stacks and O(n) search in them.
    # But the method for fetching all stack doesn't include nested stacks, so we were missing those.
    indexed_orchestration_stacks[stack_id]
  end

  def vms
    return [] if references(:vms).blank?
    references(:vms).collect do |vm_id|
      get_vm(vm_id)
    end.compact
  end

  def get_vm(uuid)
    @indexes_vms ||= {}
    return @indexes_vms[uuid] if @indexes_vms[uuid]

    @indexes_vms[uuid] = safe_get { compute_service.servers.get(uuid) }
  end

  def flavors
    return [] if references(:flavors).blank?
    return @flavors if @flavors.any?
    @flavors = references(:flavors).collect do |flavor_id|
      safe_get { compute_service.flavors.get(flavor_id) }
    end.compact
  end

  def images
    return [] unless image_service
    return [] if references(:images).blank?
    return @images if @images.any?
    @images = references(:images).collect do |image_id|
      safe_get { image_service.images.get(image_id) }
    end.compact
  end

  def tenants
    return [] if references(:cloud_tenants).blank?
    @tenants = references(:cloud_tenants).collect do |cloud_tenant_id|
      memoized_get_tenant(cloud_tenant_id)
    end.compact
  end

  def memoized_get_tenant(tenant_id)
    return nil if tenant_id.blank?
    @tenant_memo ||= identity_service.visible_tenants.index_by(&:id)
    @tenant_memo[tenant_id]
  end

  def key_pairs
    # keypair notifications from panko don't include ids, so
    # we will just refresh all the keypairs if we get an event.
    return [] if references(:key_pairs).blank?
    return @key_pairs if @key_pairs.any?
    @key_pairs = compute_service.handled_list(:key_pairs, {}, openstack_admin?)
  end

  def server_groups
    @server_groups ||= compute_service.handled_list(:server_groups, {}, openstack_admin?)
  end

  def server_group_by_vm_id
    @server_group_by_vm_id ||= server_groups.each_with_object({}) { |sg, result| sg.members.each { |vm_id| result[vm_id] = sg } }
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

  def cloud_volumes
    return [] unless volume_service
    return [] if references(:cloud_volumes).blank?
    return @cloud_volumes if @cloud_volumes.any?
    @cloud_volumes = targets_by_association(:cloud_volumes).collect do |target|
      scoped_get_volume(target.manager_ref[:ems_ref], target.options[:tenant_id])
    end.compact
  end

  def cloud_volume_snapshots
    return [] unless volume_service
    return [] if references(:cloud_volume_snapshots).blank?
    return @cloud_volume_snapshots if @cloud_volume_snapshots.any?
    @cloud_volume_snapshots = targets_by_association(:cloud_volume_snapshots).collect do |target|
      scoped_get_snapshot(target.manager_ref[:ems_ref], target.options[:tenant_id])
    end.compact
  end

  def cloud_volume_backups
    return [] unless volume_service
    # backup notifications from panko don't include ids, so
    # we will just refresh all the backups if we get an event.
    return [] if references(:cloud_volume_backups).blank?
    return @cloud_volume_backups if @cloud_volume_backups.any?
    @cloud_volume_backups = cinder_service.handled_list(:list_backups_detailed, {:__request_body_index => "backups"}, cinder_admin?)
  end

  def scoped_get_volume(volume_id, tenant_id)
    tenant = memoized_get_tenant(tenant_id)
    safe_get { @os_handle.detect_volume_service(tenant.try(:name)).volumes.get(volume_id) }
  end

  def scoped_get_snapshot(snapshot_id, tenant_id)
    tenant = memoized_get_tenant(tenant_id)
    safe_get { @os_handle.detect_volume_service(tenant.try(:name)).get_snapshot_details(snapshot_id).body["snapshot"] }
  end

  def scoped_get_backup(backup_id, tenant_id)
    tenant = memoized_get_tenant(tenant_id)
    safe_get { @os_handle.detect_volume_service(tenant.try(:name)).get_backup_details(backup_id).body["backup"] }
  end

  private

  def parse_targets!
    target.targets.each do |t|
      case t
      when Vm
        add_target!(:vms, t.ems_ref)
      when CloudTenant
        add_target!(:cloud_tenants, t.ems_ref)
      when OrchestrationStack
        add_target!(:orchestration_stacks, t.ems_ref)
      when CloudVolume
        add_target!(:cloud_volumes, t.ems_ref)
      end
    end
  end

  def infer_related_ems_refs!
    # We have a list of instances_refs collected from events. Now we want to look into our DB and API, and collect
    # ems_refs of every related object. Now this is not very nice fro ma design point of view, but we really want
    # to see changes in VM's associated objects, so the VM view is always consistent and have fresh data.
    unless references(:vms).blank?
      infer_related_vm_ems_refs_db!
      infer_related_vm_ems_refs_api!
    end
    unless references(:orchestration_stacks).blank?
      infer_related_orchestration_stacks_ems_refs_db!
      infer_related_orchestration_stacks_ems_refs_api!
    end
    unless references(:cloud_volumes).blank?
      infer_related_cloud_volumes_ems_refs_db!
      infer_related_cloud_volumes_ems_refs_api!
    end
    unless references(:cloud_tenants).blank?
      infer_related_cloud_tenant_ems_refs_db!
      # this hits the API and caches, so do this last
      infer_related_cloud_tenant_ems_refs_api!
    end
  end

  def infer_related_orchestration_stacks_ems_refs_db!
    changed_stacks = manager.orchestration_stacks.where(:ems_ref => references(:orchestration_stacks))
    changed_stacks.each do |stack|
      add_target!(:cloud_tenants, stack.cloud_tenant.ems_ref) unless stack.cloud_tenant.nil?
      add_target!(:orchestration_stacks, stack.parent.ems_ref, :tenant_id => stack.parent.cloud_tenant.ems_ref) unless stack.parent.nil?
    end
  end

  def infer_related_orchestration_stacks_ems_refs_api!
    orchestration_stacks.each do |stack|
      # Scan resources for VMs and add them as target, so the stack connects to vm, otherwise they don't connect on
      # targeted refresh
      orchestration_resources(stack).each do |resource|
        case resource.resource_type
        when "OS::Nova::Server"
          add_target!(:vms, resource.physical_resource_id)
        end
      end

      # Load all parent stacks as targets (with max_depth)
      max_depth     = 5
      counter       = 0
      current_stack = stack
      while counter < max_depth && current_stack && current_stack.parent
        add_target!(:orchestration_stacks, current_stack.parent, :tenant_id => current_stack.service.current_tenant["id"])
        counter += 1
        current_stack = get_orchestration_stack(current_stack.parent)
      end

      add_target!(:cloud_tenants, stack.service.current_tenant["id"]) unless stack.service.current_tenant["id"].blank?
    end
  end

  def infer_related_cloud_volumes_ems_refs_db!
    changed_volumes = manager.cloud_volumes.where(:ems_ref => references(:cloud_volumes))
    changed_volumes.each do |volume|
      add_target!(:cloud_tenants, volume.cloud_tenant.ems_ref) unless volume.cloud_tenant.nil?
      volume.vms.each do |vm|
        add_target!(:vms, vm.ems_ref, :tenant_id => vm.cloud_tenant.try(:ems_ref))
      end
    end
  end

  def infer_related_cloud_volumes_ems_refs_api!
    cloud_volumes.each do |volume|
      add_target!(:cloud_tenants, volume.tenant_id)
      volume.attachments.each do |attachment|
        unless attachment['server_id'].blank?
          add_target!(:vms, attachment['server_id'], :tenant_id => volume.tenant_id)
        end
      end
    end
  end

  def infer_related_cloud_tenant_ems_refs_db!
    changed_tenants = manager.cloud_tenants.where(:ems_ref => references(:cloud_tenants))
    changed_tenants.each do |tenant|
      add_target!(:cloud_tenants, tenant.parent.ems_ref) unless tenant.parent.nil?
    end
  end

  def infer_related_cloud_tenant_ems_refs_api!
    # need to reset the association cache so that tenants added by the
    # previous infer methods get picked up
    target.manager_refs_by_association_reset
    tenants.each do |tenant|
      add_target!(:cloud_tenants, tenant.try(:parent_id)) unless tenant.try(:parent_id).blank?
    end
  end

  def infer_related_vm_ems_refs_db!
    changed_vms = manager.vms.where(:ems_ref => references(:vms)).includes(:key_pairs, :network_ports, :floating_ips,
                                                                           :orchestration_stack, :cloud_networks, :cloud_tenant)
    changed_vms.each do |vm|
      stack      = vm.orchestration_stack
      all_stacks = ([stack] + (stack.try(:ancestors) || [])).compact

      all_stacks.each { |s| add_target!(:orchestration_stacks, s.ems_ref, :tenant_id => s.cloud_tenant.ems_ref) }
      vm.cloud_networks.collect(&:ems_ref).compact.each { |ems_ref| add_target!(:cloud_networks, ems_ref) }
      vm.floating_ips.collect(&:ems_ref).compact.each { |ems_ref| add_target!(:floating_ips, ems_ref) }
      vm.network_ports.collect(&:ems_ref).compact.each do |ems_ref|
        add_target!(:network_ports, ems_ref)
      end
      vm.key_pairs.collect(&:name).compact.each do |name|
        add_target!(:key_pairs, name)
      end
      vm.cloud_volumes.collect(&:ems_ref).compact.each do |ems_ref|
        add_target!(:cloud_volumes, ems_ref, :tenant_id => vm.cloud_tenant.ems_ref)
      end
      add_target!(:images, vm.parent.ems_ref) if vm.parent
      add_target!(:cloud_tenants, vm.cloud_tenant.ems_ref) if vm.cloud_tenant
    end
  end

  def infer_related_vm_ems_refs_api!
    vms.each do |vm|
      add_target!(:images, vm.image["id"])
      add_target!(:availability_zones, vm.availability_zone)
      add_target!(:key_pairs, vm.key_name) if vm.key_name
      add_target!(:cloud_tenants, vm.tenant_id)
      add_target!(:flavors, vm.flavor["id"])

      # pull the attachments from the raw attribute to avoid Fog making an unnecessary call
      # to inflate the volumes before we need them
      vm.attributes.fetch('os-extended-volumes:volumes_attached', []).each do |attachment|
        add_target!(:cloud_volumes, attachment["id"], :tenant_id => vm.tenant_id)
      end
      vm.os_interfaces.each do |iface|
        add_target!(:network_ports, iface.port_id)
        add_target!(:cloud_networks, iface.net_id)
      end
      vm.security_groups.each do |sg|
        add_target!(:security_groups, sg.id)
      end
      add_target!(:floating_ips_by_address, vm.public_ip_address) if vm.public_ip_address.present?
    end
    target.manager_refs_by_association_reset
    floating_ips.each do |floating_ip|
      add_target!(:network_routers, floating_ip.router_id)
      add_target!(:network_ports, floating_ip.port_id)
      add_target!(:cloud_networks, floating_ip.floating_network_id)
    end
  end
end

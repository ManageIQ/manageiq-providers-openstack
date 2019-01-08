class ManageIQ::Providers::Openstack::Inventory::Collector < ManageIQ::Providers::Inventory::Collector
  include ManageIQ::Providers::Openstack::RefreshParserCommon::HelperMethods
  include Vmdb::Logging

  require_nested :CloudManager
  require_nested :InfraManager
  require_nested :NetworkManager
  require_nested :StorageManager
  require_nested :TargetCollection

  attr_reader :availability_zones
  attr_reader :cloud_services
  attr_reader :tenants
  attr_accessor :flavors
  attr_reader :host_aggregates
  attr_reader :key_pairs
  attr_reader :miq_templates
  attr_reader :quotas
  attr_reader :vms
  attr_reader :vnfs
  attr_reader :vnfds
  attr_reader :cloud_networks
  attr_reader :floating_ips
  attr_reader :network_ports
  attr_reader :network_routers
  attr_reader :security_groups
  attr_reader :volume_templates
  attr_reader :volume_snapshot_templates
  attr_reader :cloud_volumes
  attr_reader :cloud_volume_snapshots
  attr_reader :cloud_volume_backups
  attr_reader :cloud_volume_types
  attr_reader :hosts
  attr_reader :object_store
  attr_reader :stack_server_resources
  attr_reader :stack_server_resource_types
  attr_reader :stack_resource_groups
  attr_reader :stack_resources

  def initialize(_manager, _target)
    super

    initialize_inventory_sources
  end

  def initialize_inventory_sources
    # common
    @images                      = []
    @orchestration_stacks        = nil
    @tenants                     = []
    # cloud
    @availability_zones          = []
    @cloud_services              = []
    @flavors                     = []
    @host_aggregates             = []
    @key_pairs                   = []
    @quotas                      = []
    @vms                         = []
    @vnfs                        = []
    @vnfds                       = []
    @volume_templates            = []
    @volume_snapshot_templates   = []
    # infra
    @hosts                       = []
    @servers                     = []
    @object_store                = []
    @stack_server_resources      = []
    @stack_server_resource_types = []
    @stack_resource_groups       = nil
    @stack_resources             = []
    @root_stacks                 = []
    # network
    @cloud_networks              = []
    @cloud_subnets               = []
    @floating_ips                = []
    @network_ports               = []
    @network_routers             = []
    @security_groups             = []
    # cinder
    @cloud_volumes               = []
    @cloud_volume_snapshots      = []
    @cloud_volume_backups        = []
    @cloud_volume_types          = []
  end

  def connection
    @os_handle ||= manager.openstack_handle
    @connection ||= manager.connect
  end

  def compute_service
    connection
  end

  def identity_service
    @identity_service ||= manager.openstack_handle.identity_service
  end

  def image_service
    @image_service ||= manager.openstack_handle.detect_image_service
  end

  def network_service
    @network_service ||= manager.openstack_handle.detect_network_service
  end

  def nfv_service
    @nfv_service ||= manager.openstack_handle.detect_nfv_service
  end

  def volume_service
    @volume_service ||= manager.openstack_handle.detect_volume_service
  end

  def orchestration_service
    @orchestration_service ||= manager.openstack_handle.detect_orchestration_service
  end

  def baremetal_service
    @baremetal_service ||= manager.openstack_handle.detect_baremetal_service
  end

  def storage_service
    @storage_service ||= manager.openstack_handle.detect_storage_service
  end

  def introspection_service
    @introspection_service ||= manager.openstack_handle.detect_introspection_service
  end

  def images
    return @images if @images.any?
    @images = if openstack_admin?
                image_service.images_with_pagination_loop
              else
                image_service.handled_list(:images)
              end
  end

  def orchestration_stacks(show_nested = true)
    return orchestration_stacks_with_nested if show_nested
    orchestration_stacks_without_nested
  end

  def orchestration_stacks_with_nested
    @orchestration_stacks_with_nested ||= load_stacks
  end

  def orchestration_stacks_without_nested
    @orchestration_stacks_without_nested ||= load_stacks(false)
  end

  def load_stacks(show_nested = true)
    return [] unless orchestration_service
    # TODO(lsmola) We need a support of GET /{tenant_id}/stacks/detail in FOG, it was implemented here
    # https://review.openstack.org/#/c/35034/, but never documented in API reference, so right now we
    # can't get list of detailed stacks in one API call.
    if openstack_heat_global_admin?
      orchestration_service.handled_list(:stacks, {:show_nested => show_nested, :global_tenant => true}, true).collect(&:details)
    else
      orchestration_service.handled_list(:stacks, :show_nested => show_nested).collect(&:details)
    end
  rescue Excon::Errors::Forbidden
    # Orchestration service is detected but not open to the user
    _log.warn("Skip refreshing stacks because the user cannot access the orchestration service")
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
end

class ManageIQ::Providers::Openstack::Inventory::Collector < ManageIQ::Providers::Inventory::Collector
  include ManageIQ::Providers::Openstack::RefreshParserCommon::HelperMethods
  include Vmdb::Logging

  require_nested :CloudManager
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
  attr_reader :orchestration_stacks
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
  attr_reader :servers
  attr_reader :hosts

  def initialize(_manager, _target)
    super

    initialize_inventory_sources
  end

  def initialize_inventory_sources
    # cloud
    @availability_zones_compute = []
    @availability_zones_volume  = []
    @cloud_services             = []
    @tenants                    = []
    @flavors                    = []
    @host_aggregates            = []
    @key_pairs                  = []
    @images                     = []
    @orchestration_stacks       = nil
    @quotas                     = []
    @vms                        = []
    @vnfs                       = []
    @vnfds                      = []
    @volume_templates           = []
    @volume_snapshot_templates  = []
    # network
    @cloud_networks             = []
    @cloud_subnets              = []
    @floating_ips               = []
    @network_ports              = []
    @network_routers            = []
    @security_groups            = []
    @firewall_rules             = []
    # cinder
    @cloud_volumes              = []
    @cloud_volume_snapshots     = []
    @cloud_volume_backups       = []
    @cloud_volume_types         = []

    # infra
    @servers                    = []
    @hosts                      = []
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

  def all_orchestration_stacks
    return [] unless orchestration_service
    # TODO(lsmola) We need a support of GET /{tenant_id}/stacks/detail in FOG, it was implemented here
    # https://review.openstack.org/#/c/35034/, but never documented in API reference, so right now we
    # can't get list of detailed stacks in one API call.
    return @all_orchestration_stacks unless @all_orchestration_stacks.nil?

    @all_orchestration_stacks = if openstack_heat_global_admin?
                                  orchestration_service.handled_list(:stacks, {:show_nested => true, :global_tenant => true}, true).collect(&:details)
                                else
                                  orchestration_service.handled_list(:stacks, :show_nested => true).collect(&:details)
                                end
  rescue Excon::Errors::Forbidden
    # Orchestration service is detected but not open to the user
    log.warn("Skip refreshing stacks because the user cannot access the orchestration service")
    []
  end
end

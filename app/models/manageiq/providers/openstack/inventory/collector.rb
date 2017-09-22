class ManageIQ::Providers::Openstack::Inventory::Collector < ManagerRefresh::Inventory::Collector
  include ManageIQ::Providers::Openstack::RefreshParserCommon::HelperMethods
  include Vmdb::Logging

  require_nested :CloudManager
  require_nested :NetworkManager
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

  def initialize(_manager, _target)
    super

    initialize_inventory_sources
  end

  def initialize_inventory_sources
    # cloud
    @availability_zones   = []
    @cloud_services       = []
    @tenants              = []
    @flavors              = []
    @host_aggregates      = []
    @key_pairs            = []
    @images               = []
    @orchestration_stacks = []
    @quotas               = []
    @vms                  = []
    @vnfs                 = []
    @vnfds                = []
    @volume_templates     = []
    # network
    @cloud_networks       = []
    @floating_ips         = []
    @network_ports        = []
    @network_routers      = []
    @security_groups      = []
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
end

class ManageIQ::Providers::Openstack::CloudManager < ManageIQ::Providers::CloudManager
  require_nested :AuthKeyPair
  require_nested :AvailabilityZone
  require_nested :AvailabilityZoneNull
  require_nested :CloudResourceQuota
  require_nested :CloudTenant
  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :Flavor
  require_nested :HostAggregate
  require_nested :MetricsCapture
  require_nested :MetricsCollectorWorker
  require_nested :OrchestrationServiceOptionConverter
  require_nested :OrchestrationStack
  require_nested :OrchestrationTemplate
  require_nested :VnfdTemplate
  require_nested :PlacementGroup
  require_nested :Provision
  require_nested :ProvisionWorkflow
  require_nested :Refresher
  require_nested :RefreshWorker
  require_nested :Snapshot
  require_nested :Template
  require_nested :Vm

  has_one :network_manager,
          :foreign_key => :parent_ems_id,
          :class_name  => "ManageIQ::Providers::Openstack::NetworkManager",
          :autosave    => true,
          :dependent   => :destroy
  has_many :storage_managers,
           :foreign_key => :parent_ems_id,
           :class_name  => "ManageIQ::Providers::StorageManager",
           :autosave    => true,
           :dependent   => :destroy
  has_many :snapshots, :through => :vms_and_templates
  include ManageIQ::Providers::Openstack::CinderManagerMixin
  include ManageIQ::Providers::Openstack::SwiftManagerMixin
  include ManageIQ::Providers::Openstack::ManagerMixin
  include ManageIQ::Providers::Openstack::IdentitySyncMixin

  supports :catalog
  supports :create
  supports :provisioning
  supports :cloud_tenants
  supports :cloud_tenant_mapping do
    if defined?(self.class.module_parent::CloudManager::CloudTenant) && !tenant_mapping_enabled?
      unsupported_reason_add(:cloud_tenant_mapping, _("Tenant mapping is disabled on the Provider"))
    elsif !defined?(self.class.module_parent::CloudManager::CloudTenant)
      unsupported_reason_add(:cloud_tenant_mapping, _("Tenant mapping is supported only when CloudTenant exists "\
                                                      "on the CloudManager"))
    end
  end
  supports :create_flavor
  supports :label_mapping
  supports :events do
    unsupported_reason_add(:events, _("Events are not supported")) unless capabilities["events"]
  end
  supports :metrics
  supports :storage_manager

  supports :cinder_service do
    unsupported_reason_add(:cinder_service, "Cinder service unavailable") unless openstack_handle.detect_volume_service.name == :cinder
  end

  supports :swift_service do
    unsupported_reason_add(:swift_service, "Swift service unavailable") unless openstack_handle.detect_volume_service.name == :swift
  end

  before_create :ensure_managers

  before_update :ensure_managers_zone_and_provider_region
  after_save :refresh_parent_infra_manager

  private_class_method def self.provider_id_options
    t = ManageIQ::Providers::Openstack::Provider
    Rbac
      .filtered(t.order(t.arel_table[:name].lower))
      .pluck(:name, :id)
      .map do |name, id|
        {
          :label => name,
          :value => id.to_s,
        }
      end
  end

  def self.params_for_create
    {
      :fields => [
        {
          :component => "text-field",
          :id        => "provider_region",
          :name      => "provider_region",
          :label     => _("Provider Region"),
        },
        {
          :component   => "select",
          :id          => "provider_id",
          :name        => "provider_id",
          :label       => _("Openstack Infra Provider"),
          :isClearable => true,
          :simpleValue => true,
          :options     => provider_id_options,
        },
        {
          :component    => "select",
          :id           => "api_version",
          :name         => "api_version",
          :label        => _("API Version"),
          :initialValue => 'v3',
          :isRequired   => true,
          :validate     => [{:type => "required"}],
          :options      => [
            {
              :label => 'Keystone V2',
              :value => 'v2',
            },
            {
              :label => 'Keystone V3',
              :value => 'v3',
            },
          ],
        },
        {
          :component  => 'text-field',
          :id         => 'uid_ems',
          :name       => 'uid_ems',
          :label      => _('Domain ID'),
          :isRequired => true,
          :condition  => {
            :when => 'api_version',
            :is   => 'v3',
          },
          :validate   => [{
            :type      => "required",
            :condition => {
              :when => 'api_version',
              :is   => 'v3',
            }
          }],
        },
        {
          :component => 'switch',
          :id        => 'tenant_mapping_enabled',
          :name      => 'tenant_mapping_enabled',
          :label     => _('Tenant Mapping Enabled'),
        },
        {
          :component => 'sub-form',
          :id        => 'endpoints-subform',
          :name      => 'endpoints-subform',
          :title     => _('Endpoints'),
          :fields    => [
            {
              :component => 'sub-form',
              :id        => 'default-tab',
              :name      => 'default-tab',
              :title     => _('Default'),
              :fields    => [
                {
                  :component              => 'validate-provider-credentials',
                  :id                     => 'authentications.default.valid',
                  :name                   => 'authentications.default.valid',
                  :skipSubmit             => true,
                  :isRequired             => true,
                  :validationDependencies => %w[name type api_version provider_region uid_ems],
                  :fields                 => [
                    {
                      :component    => "select",
                      :id           => "endpoints.default.security_protocol",
                      :name         => "endpoints.default.security_protocol",
                      :label        => _("Security Protocol"),
                      :isRequired   => true,
                      :initialValue => 'ssl-with-validation',
                      :validate     => [{:type => "required"}],
                      :options      => [
                        {
                          :label => _("SSL without validation"),
                          :value => "ssl-no-validation"
                        },
                        {
                          :label => _("SSL"),
                          :value => "ssl-with-validation"
                        },
                        {
                          :label => _("Non-SSL"),
                          :value => "non-ssl"
                        }
                      ]
                    },
                    {
                      :component  => "text-field",
                      :id         => "endpoints.default.hostname",
                      :name       => "endpoints.default.hostname",
                      :label      => _("Hostname (or IPv4 or IPv6 address)"),
                      :isRequired => true,
                      :validate   => [{:type => "required"}],
                    },
                    {
                      :component    => "text-field",
                      :id           => "endpoints.default.port",
                      :name         => "endpoints.default.port",
                      :label        => _("API Port"),
                      :type         => "number",
                      :initialValue => 13_000,
                      :isRequired   => true,
                      :validate     => [{:type => "required"}],
                    },
                    {
                      :component  => "text-field",
                      :id         => "authentications.default.userid",
                      :name       => "authentications.default.userid",
                      :label      => _("Username"),
                      :isRequired => true,
                      :validate   => [{:type => "required"}],
                    },
                    {
                      :component  => "password-field",
                      :id         => "authentications.default.password",
                      :name       => "authentications.default.password",
                      :label      => _("Password"),
                      :type       => "password",
                      :isRequired => true,
                      :validate   => [{:type => "required"}],
                    },
                    {
                      :component => 'sub-form',
                      :id        => 'events-tab',
                      :name      => 'events-tab',
                      :title     => _('Events'),
                      :fields    => [
                        {
                          :component    => 'protocol-selector',
                          :id           => 'event_stream_selection',
                          :name         => 'event_stream_selection',
                          :initialValue => 'none',
                          :label        => _('Type'),
                          :options      => [
                            {
                              :label => _('Disabled'),
                              :value => 'none',
                            },
                            {
                              :label => _('Ceilometer'),
                              :value => 'ceilometer',
                              :pivot => 'endpoints.ceilometer.hostname'
                            },
                            {
                              :label => _('STF'),
                              :value => 'stf',
                              :pivot => 'endpoints.stf.hostname',
                            },
                            {
                              :label => _('AMQP'),
                              :value => 'amqp',
                              :pivot => 'endpoints.amqp.hostname',
                            },
                          ],
                        },
                        {
                          :component              => 'sub-form',
                          :id                     => 'endpoints.amqp.valid',
                          :name                   => 'endpoints.amqp.valid',
                          :validationDependencies => %w[type event_stream_selection],
                          :condition              => {
                            :when => 'event_stream_selection',
                            :is   => 'amqp',
                          },
                          :fields                 => [
                            {
                              :component  => "text-field",
                              :id         => "endpoints.amqp.hostname",
                              :name       => "endpoints.amqp.hostname",
                              :label      => _("Hostname (or IPv4 or IPv6 address)"),
                              :isRequired => true,
                              :validate   => [{:type => "required"}],
                            },
                            {
                              :component    => "text-field",
                              :id           => "endpoints.amqp.port",
                              :name         => "endpoints.amqp.port",
                              :label        => _("API Port"),
                              :type         => "number",
                              :isRequired   => true,
                              :initialValue => 5672,
                              :validate     => [{:type => "required"}],
                            },
                            {
                              :component  => "text-field",
                              :id         => "authentications.amqp.userid",
                              :name       => "authentications.amqp.userid",
                              :label      => _("Username"),
                              :isRequired => true,
                              :validate   => [{:type => "required"}],
                            },
                            {
                              :component  => "password-field",
                              :id         => "authentications.amqp.password",
                              :name       => "authentications.amqp.password",
                              :label      => _("Password"),
                              :type       => "password",
                              :isRequired => true,
                              :validate   => [{:type => "required"}],
                            },
                          ],
                        },
                        {
                          :component              => 'sub-form',
                          :id                     => 'endpoints.stf.valid',
                          :name                   => 'endpoints.stf.valid',
                          :validationDependencies => %w[type event_stream_selection],
                          :condition              => {
                            :when => 'event_stream_selection',
                            :is   => 'stf',
                          },
                          :fields                 => [
                            {
                              :component    => "select",
                              :id           => "endpoints.stf.security_protocol",
                              :name         => "endpoints.stf.security_protocol",
                              :label        => _("Security Protocol"),
                              :isRequired   => true,
                              :initialValue => 'ssl-with-validation',
                              :validate     => [{:type => "required"}],
                              :options      => [
                                {
                                  :label => _("SSL without validation"),
                                  :value => "ssl-no-validation"
                                },
                                {
                                  :label => _("SSL"),
                                  :value => "ssl-with-validation"
                                },
                                {
                                  :label => _("Non-SSL"),
                                  :value => "non-ssl"
                                }
                              ]
                            },
                            {
                              :component  => "text-field",
                              :id         => "endpoints.stf.hostname",
                              :name       => "endpoints.stf.hostname",
                              :label      => _("Hostname (or IPv4 or IPv6 address)"),
                              :isRequired => true,
                              :validate   => [{:type => "required"}],
                            },
                            {
                              :component    => "text-field",
                              :id           => "endpoints.stf.port",
                              :name         => "endpoints.stf.port",
                              :label        => _("API Port"),
                              :type         => "number",
                              :isRequired   => true,
                              :initialValue => 5666,
                              :validate     => [{:type => "required"}],
                            },
                          ]
                        }
                      ],
                    },
                  ]
                },
              ]
            },
            {
              :component => 'sub-form',
              :id        => 'ssh_keypair-tab',
              :name      => 'ssh_keypair-tab',
              :title     => _('RSA key pair'),
              :fields    => [
                :component => 'provider-credentials',
                :id        => 'endpoints.ssh_keypair.valid',
                :name      => 'endpoints.ssh_keypair.valid',
                :fields    => [
                  {
                    :component    => 'text-field',
                    :hideField    => true,
                    :label        => 'ssh_keypair',
                    :id           => 'endpoints.ssh_keypair',
                    :name         => 'endpoints.ssh_keypair',
                    :initialValue => '',
                    :condition    => {
                      :when       => 'authentications.ssh_keypair.userid',
                      :isNotEmpty => true,
                    },
                  },
                  {
                    :component => "text-field",
                    :id        => "authentications.ssh_keypair.userid",
                    :name      => "authentications.ssh_keypair.userid",
                    :label     => _("Username"),
                  },
                  {
                    :component      => "password-field",
                    :id             => "authentications.ssh_keypair.auth_key",
                    :name           => "authentications.ssh_keypair.auth_key",
                    :componentClass => 'textarea',
                    :rows           => 10,
                    :label          => _("Private Key"),
                  },
                ],
              ],
            },
          ],
        },
      ]
    }
  end

  def self.build_ceilometer_endpoint!(params, endpoints, _authentications)
    if params.delete("event_stream_selection") == "ceilometer"
      default_endpoint = endpoints.detect { |ep| ep["role"] == "default" }
      endpoints << {"role" => "ceilometer", "hostname" => default_endpoint["hostname"]}
    end
  end

  def self.create_from_params(params, endpoints, authentications)
    build_ceilometer_endpoint!(params, endpoints, authentications)

    super
  end

  def edit_with_params(params, endpoints, authentications)
    self.class.build_ceilometer_endpoint!(params, endpoints, authentications)

    super
  end

  def hostname_required?
    enabled?
  end

  def refresh_parent_infra_manager
    # If the cloud manager had a new/different infra manager attached to it
    # during this save, refresh the infra manager.
    if provider_id && (attribute_before_last_save(:provider_id) != provider_id) && provider.infra_ems
      EmsRefresh.queue_refresh(provider.infra_ems)
      _log.info("EMS: [#{name}] refreshing attached infra manager [#{provider.infra_ems.name}]")
    end
  end

  def ensure_managers
    ensure_network_manager
    ensure_cinder_manager
    ensure_swift_manager
    ensure_managers_zone_and_provider_region
  end

  def ensure_managers_zone_and_provider_region
    if network_manager
      network_manager.enabled         = enabled
      network_manager.zone_id         = zone_id
      network_manager.tenant_id       = tenant_id
      network_manager.provider_region = provider_region
    end

    if cinder_manager
      cinder_manager.enabled         = enabled
      cinder_manager.zone_id         = zone_id
      cinder_manager.tenant_id       = tenant_id
      cinder_manager.provider_region = provider_region
    end

    if swift_manager
      swift_manager.enabled         = enabled
      swift_manager.zone_id         = zone_id
      swift_manager.tenant_id       = tenant_id
      swift_manager.provider_region = provider_region
    end
  end

  def ensure_network_manager
    build_network_manager unless network_manager
  end

  def ensure_cinder_manager
    build_cinder_manager unless cinder_manager
  end

  def ensure_swift_manager
    build_swift_manager unless swift_manager
  end

  after_save :save_on_other_managers

  def save_on_other_managers
    storage_managers.update_all(:tenant_mapping_enabled => tenant_mapping_enabled)
    if network_manager
      network_manager.tenant_mapping_enabled = tenant_mapping_enabled
      network_manager.save!
    end
  end

  def cinder_service
    vs = openstack_handle.detect_volume_service
    vs&.name == :cinder ? vs : nil
  end

  def swift_service
    vs = openstack_handle.detect_storage_service
    vs&.name == :swift ? vs : nil
  end

  def self.ems_type
    @ems_type ||= "openstack".freeze
  end

  def self.description
    @description ||= "OpenStack".freeze
  end

  def self.vm_vendor
    @vm_vendor ||= "openstack".freeze
  end

  def self.default_blacklisted_event_names
    %w(
      identity.authenticate
      scheduler.run_instance.start
      scheduler.run_instance.scheduled
      scheduler.run_instance.end
    )
  end

  def self.api_allowed_attributes
    %w[keystone_v3_domain_id].freeze
  end

  def hostname_uniqueness_valid?
    return unless hostname_required?
    return unless hostname.present? # Presence is checked elsewhere

    existing_providers = Endpoint.where(:hostname => hostname.downcase)
                                 .where.not(:resource_id => id).includes(:resource)
                                 .select do |endpoint|
                                   unless endpoint.resource.nil?
                                     endpoint.resource.uid_ems == keystone_v3_domain_id &&
                                       endpoint.resource.provider_region == provider_region
                                   end
                                 end

    errors.add(:hostname, "has already been taken") if existing_providers.any?
  end

  def supported_auth_types
    %w(default amqp ssh_keypair)
  end

  def block_storage_manager
    cinder_manager
  end

  def self.catalog_types
    {"openstack" => N_("OpenStack")}
  end

  def required_credential_fields(type)
    case type.to_s
    when 'ssh_keypair' then [:userid, :auth_key]
    else                    [:userid, :password]
    end
  end

  def authentication_status_ok?(type = nil)
    return true if type == :ssh_keypair
    super
  end

  def authentications_to_validate
    authentication_for_providers.collect(&:authentication_type) - [:ssh_keypair]
  end

  def volume_availability_zones
    availability_zones.where("'volume' = ANY(provider_services_supported)")
  end

  def allow_targeted_refresh?
    true
  end

  #
  # Operations
  #

  def vm_create_snapshot(vm, options = {})
    log_prefix = "vm=[#{vm.name}]"

    compute_service = openstack_handle.compute_service(vm.cloud_tenant.name)
    snapshot = compute_service.create_image(vm.ems_ref, options[:name], :description   => options[:desc],
                                                                        :instance_uuid => vm.ems_ref).body["image"]

    Notification.create(:type => :vm_snapshot_success, :subject => vm, :options => {:snapshot_op => 'create'})
    snapshot_id = snapshot["id"]

    return snapshot_id
  rescue => err
    _log.error "#{log_prefix}, error: #{err}"
    _log.debug { err.backtrace.join("\n") }
    raise MiqException::MiqOpenstackApiRequestError, parse_error_message_from_fog_response(err)
  end

  def vm_remove_snapshot(vm, options = {})
    require 'OpenStackExtract/MiqOpenStackVm/MiqOpenStackInstance'

    snapshot_uid = options[:snMor]

    log_prefix = "snapshot=[#{snapshot_uid}]"

    miq_openstack_instance = MiqOpenStackInstance.new(vm.ems_ref, openstack_handle)
    miq_openstack_instance.delete_evm_snapshot(snapshot_uid)
    Notification.create(:type => :vm_snapshot_success, :subject => vm, :options => {:snapshot_op => 'remove'})

    # Remove from the snapshots table.
    ar_snapshot = vm.snapshots.find_by(:ems_ref  => snapshot_uid)
    _log.debug "#{log_prefix}: ar_snapshot = #{ar_snapshot.class.name}"
    ar_snapshot.destroy if ar_snapshot

    # Remove from the vms table.
    ar_template = miq_templates.find_by(:ems_ref  => snapshot_uid)
    _log.debug "#{log_prefix}: ar_template = #{ar_template.class.name}"
    ar_template.destroy if ar_template
  rescue => err
    _log.error "#{log_prefix}, error: #{err}"
    _log.debug { err.backtrace.join("\n") }
    raise
  end

  def vm_remove_all_snapshots(vm, _options = {})
    vm.snapshots.each { |snapshot| vm_remove_snapshot(vm, :snMor => snapshot.uid) }
  end

  # TODO: Should this be in a VM-specific subclass or mixin?
  #       This is a general EMS question.
  def vm_create_evm_snapshot(vm, options = {})
    require "OpenStackExtract/MiqOpenStackVm/MiqOpenStackInstance"

    log_prefix = "vm=[#{vm.name}]"

    miq_openstack_instance = MiqOpenStackInstance.new(vm.ems_ref, openstack_handle)
    miq_snapshot = miq_openstack_instance.create_evm_snapshot(options)

    # Add new snapshot image to the vms table. Type is TemplateOpenstack.
    miq_templates.create!(
      :type     => "ManageIQ::Providers::Openstack::CloudManager::Template",
      :vendor   => "openstack",
      :name     => miq_snapshot.name,
      :uid_ems  => miq_snapshot.id,
      :ems_ref  => miq_snapshot.id,
      :template => true,
      :location => "unknown"
    )

    # Add new snapshot to the snapshots table.
    vm.snapshots.create!(
      :name        => miq_snapshot.name,
      :description => options[:desc],
      :uid         => miq_snapshot.id,
      :uid_ems     => miq_snapshot.id,
      :ems_ref     => miq_snapshot.id
    )
    return miq_snapshot.id
  rescue => err
    _log.error "#{log_prefix}, error: #{err}"
    _log.debug { err.backtrace.join("\n") }
    raise
  end

  def vm_delete_evm_snapshot(vm, image_id)
    require "OpenStackExtract/MiqOpenStackVm/MiqOpenStackInstance"

    log_prefix = "snapshot=[#{image_id}]"

    miq_openstack_instance = MiqOpenStackInstance.new(vm.ems_ref, openstack_handle)
    miq_openstack_instance.delete_evm_snapshot(image_id)

    # Remove from the snapshots table.
    ar_snapshot = vm.snapshots.find_by(:ems_ref  => image_id)
    _log.debug "#{log_prefix}: ar_snapshot = #{ar_snapshot.class.name}"
    ar_snapshot.destroy if ar_snapshot

    # Remove from the vms table.
    ar_template = miq_templates.find_by(:ems_ref  => image_id)
    _log.debug "#{log_prefix}: ar_template = #{ar_template.class.name}"
    ar_template.destroy if ar_template
  rescue => err
    _log.error "#{log_prefix}, error: #{err}"
    _log.debug { err.backtrace.join("\n") }
    raise
  end

  def vm_attach_volume(vm, options)
    volume = CloudVolume.find_by(:id => options[:volume_id])
    volume.raw_attach_volume(vm.ems_ref, options[:device])
  end

  def vm_detach_volume(vm, options)
    volume = CloudVolume.find_by(:id => options[:volume_id])
    volume.raw_detach_volume(vm.ems_ref)
  end

  def create_host_aggregate(options)
    ManageIQ::Providers::Openstack::CloudManager::HostAggregate.create_aggregate(self, options)
  end

  def create_host_aggregate_queue(userid, options)
    ManageIQ::Providers::Openstack::CloudManager::HostAggregate.create_aggregate_queue(userid, self, options)
  end

  def self.event_monitor_class
    ManageIQ::Providers::Openstack::CloudManager::EventCatcher
  end

  #
  # Statistics
  #

  def block_storage_disk_usage
    cloud_volumes.where.not(:status => "error").sum(:size).to_f +
      cloud_volume_snapshots.where.not(:status => "error").sum(:size).to_f
  end

  def object_storage_disk_usage(swift_replicas = 1)
    cloud_object_store_containers.sum(:bytes).to_f * swift_replicas
  end

  def self.display_name(number = 1)
    n_('Cloud Provider (OpenStack)', 'Cloud Providers (OpenStack)', number)
  end

  LABEL_MAPPING_ENTITIES = {
    "VmOpenstack" => "ManageIQ::Providers::Openstack::CloudManager::Vm"
  }.freeze

  def self.entities_for_label_mapping
    LABEL_MAPPING_ENTITIES
  end

  def self.label_mapping_prefix
    ems_type
  end
end

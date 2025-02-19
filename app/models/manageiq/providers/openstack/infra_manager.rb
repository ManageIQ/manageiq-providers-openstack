class ManageIQ::Providers::Openstack::InfraManager < ManageIQ::Providers::InfraManager
  include ManageIQ::Providers::Openstack::ManagerMixin
  include HasManyOrchestrationStackMixin
  include HasNetworkManagerMixin

  before_save :ensure_parent_provider
  before_destroy :destroy_parent_provider
  before_create :ensure_managers
  before_update :ensure_managers_zone_and_provider_region

  supports :create
  supports :catalog
  supports :metrics
  supports :events do
    _("Events are not supported") unless capabilities["events"]
  end
  supports_not :shutdown

  def self.params_for_create
    {
      :fields => [
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
          :component => 'sub-form',
          :id        => 'endpoints-subform',
          :name      => 'endpoints-subform',
          :title     => _('Endpoints'),
          :fields    => [
            :component => 'tabs',
            :name      => 'tabs',
            :fields    => [
              {
                :component => 'tab-item',
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
                    :validationDependencies => %w[name type zone_id api_version provider_region keystone_v3_domain_id],
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
                    ]
                  },
                ]
              },
              {
                :component => 'tab-item',
                :id        => 'events-tab',
                :name      => 'events-tab',
                :title     => _('Events'),
                :fields    => [
                  {
                    :component    => 'protocol-selector',
                    :id           => 'event_stream_selection',
                    :name         => 'event_stream_selection',
                    :skipSubmit   => true,
                    :initialValue => 'ceilometer',
                    :label        => _('Type'),
                    :options      => [
                      {
                        :label => _('Ceilometer'),
                        :value => 'ceilometer',
                      },
                      {
                        :label => _('AMQP'),
                        :value => 'amqp',
                        :pivot => 'endpoints.amqp.hostname',
                      },
                    ],
                  },
                  {
                    :component    => 'text-field',
                    :type         => 'hidden',
                    :id           => 'endpoints.ceilometer',
                    :name         => 'endpoints.ceilometer',
                    :initialValue => {},
                    :condition    => {
                      :when => 'event_stream_selection',
                      :is   => 'ceilometer',
                    },
                  },
                  {
                    :component              => 'validate-provider-credentials',
                    :id                     => 'endpoints.amqp.valid',
                    :name                   => 'endpoints.amqp.valid',
                    :skipSubmit             => true,
                    :isRequired             => true,
                    :validationDependencies => %w[type zone_id event_stream_selection],
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
                ],
              },
              {
                :component => 'tab-item',
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
                      :type         => 'hidden',
                      :id           => 'endpoints.ssh_keypair',
                      :name         => 'endpoints.ssh_keypair',
                      :initialValue => {},
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
          ],
        },
      ]
    }
  end

  def ensure_network_manager
    build_network_manager(:type => 'ManageIQ::Providers::Openstack::NetworkManager') unless network_manager
  end

  def allow_targeted_refresh?
    false
  end

  # A placeholder relation for NetworkTopology to work
  def availability_zones
  end

  def cloud_tenants
    self.class.none
  end

  def host_aggregates
    HostAggregate.where(:ems_id => provider.try(:cloud_ems).try(:collect, &:id).try(:uniq))
  end

  def ensure_parent_provider
    # TODO(lsmola) this might move to a general management of Providers, but for now, we will ensure, every
    # EmsOpenstackInfra has associated a Provider. This relation will serve for relating EmsOpenstackInfra
    # to possible many EmsOpenstacks deployed through EmsOpenstackInfra

    # Name of the provider needs to be unique, get provider if there is one like that
    self.provider = ManageIQ::Providers::Openstack::Provider.find_by(:name => name) unless provider

    attributes = {:name => name, :zone => zone}
    if provider
      provider.update!(attributes)
    else
      self.provider = ManageIQ::Providers::Openstack::Provider.create!(attributes)
    end
  end

  def destroy_parent_provider
    provider.try(:destroy)
  end

  def self.ems_type
    @ems_type ||= "openstack_infra".freeze
  end

  def self.description
    @description ||= "OpenStack Platform Director".freeze
  end

  def supported_auth_types
    %w(default amqp ssh_keypair)
  end

  def supported_auth_attributes
    %w(userid password auth_key)
  end

  def self.catalog_types
    {"openstack" => N_("OpenStack")}
  end

  def self.event_monitor_class
    ManageIQ::Providers::Openstack::InfraManager::EventCatcher
  end

  def verify_credentials(auth_type = nil, options = {})
    options[:service] ||= "Baremetal"

    super
  end

  def required_credential_fields(type)
    case type.to_s
    when 'ssh_keypair' then [:userid, :auth_key]
    else                    [:userid, :password]
    end
  end

  def verify_ssh_keypair_credentials(_options)
    # Select one powered-on host in each cluster to verify
    # ssh credentials against
    hosts.select(&:ems_cluster_id)
         .sort_by(&:ems_cluster_id)
         .slice_when { |i, j| i.ems_cluster_id != j.ems_cluster_id }
         .map { |c| c.find { |h| h.power_state == 'on' } }.compact
         .all? { |h| h.verify_credentials('ssh_keypair') }
  end
  private :verify_ssh_keypair_credentials

  def workflow_service
    openstack_handle.detect_workflow_service
  end

  def register_and_configure_nodes(nodes_json)
    connection = openstack_handle.detect_workflow_service
    workflow = "tripleo.baremetal.v1.register_or_update"
    input = { :nodes_json => nodes_json }
    response = connection.create_execution(workflow, input)
    state = response.body["state"]
    workflow_execution_id = response.body["id"]

    while state == "RUNNING"
      sleep 5
      response = connection.get_execution(workflow_execution_id)
      state = response.body["state"]
    end

    EmsRefresh.queue_refresh(@infra) if state == "SUCCESS"

    # Configures boot image for all manageable nodes.
    # It would be preferred to only configure the nodes that were just added, but
    # we don't know the uuids from the response. The uuids are available in Zaqar.
    # Once we add support for reading Zaqar, we can change this to be more
    # selective.
    connection.create_execution("tripleo.baremetal.v1.configure_manageable_nodes")

    [state, response.body.to_s]
  end

  def self.display_name(number = 1)
    n_('Infrastructure Provider (OpenStack)', 'Infrastructure Providers (OpenStack)', number)
  end

  private

  def authentication_class(attributes)
    attributes.symbolize_keys[:auth_key] ? ManageIQ::Providers::Openstack::InfraManager::AuthKeyPair : super
  end
end

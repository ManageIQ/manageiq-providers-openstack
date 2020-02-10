module ManageIQ::Providers::Openstack::ManagerMixin
  extend ActiveSupport::Concern
  include ManageIQ::Providers::Openstack::HelperMethods

  included do
    after_save :stop_event_monitor_queue_on_change
    before_destroy :stop_event_monitor
  end

  alias_attribute :keystone_v3_domain_id, :uid_ems
  #
  # OpenStack interactions
  #
  module ClassMethods
    def amqp_available?(password, params)
      require 'manageiq/providers/openstack/legacy/events/openstack_rabbit_event_monitor'
      OpenstackRabbitEventMonitor.available?(
        :hostname => params[:amqp_hostname],
        :username => params[:amqp_userid],
        :password => ManageIQ::Password.try_decrypt(password),
        :port     => params[:amqp_api_port]
      )
    end
    private :amqp_available?

    def ems_connect?(password, params, service)
      ems = new
      ems.name                   = params[:name].strip
      ems.provider_region        = params[:provider_region]
      ems.api_version            = params[:api_version].strip
      ems.security_protocol      = params[:default_security_protocol].strip
      ems.keystone_v3_domain_id  = params[:keystone_v3_domain_id]

      user, hostname, port = params[:default_userid], params[:default_hostname].strip, params[:default_api_port].strip

      endpoint = {:role => :default, :hostname => hostname, :port => port, :security_protocol => ems.security_protocol}
      authentication = {:userid => user, :password => ManageIQ::Password.try_decrypt(password), :save => false, :role => 'default', :authtype => 'default'}
      ems.connection_configurations = [{:endpoint       => endpoint,
                                        :authentication => authentication}]

      begin
        ems.connect(:service => service)
      rescue => err
        miq_exception = translate_exception(err)
        raise unless miq_exception

        _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
        raise miq_exception
      end
    end
    private :ems_connect?

    def params_for_create
      @params_for_create ||= {
        :fields => [
          {
            :component => "text-field",
            :name      => "provider_region",
            :label     => _("Provider Region"),
          },
          {
            :component    => "select-field",
            :name         => "api_version",
            :label        => _("API Version"),
            :initialValue => 'v2',
            :isRequired   => true,
            :validate     => [{:type => "required-validator"}],
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
            :name       => 'keystone_v3_domain_id',
            :label      => _('Domain ID'),
            :isRequired => true,
            :condition  => {
              :when => 'api_version',
              :is   => 'v3',
            },
            :validate   => [{
              :type      => "required-validator",
              :condition => {
                :when => 'api_version',
                :is   => 'v3',
              }
            }],
          },
          {
            :component => 'switch-field',
            :name      => 'tenant_mapping_enabled',
            :label     => _('Tenant Mapping Enabled'),
          },
          {
            :component => 'sub-form',
            :name      => 'endpoints',
            :title     => _('Endpoints'),
            :fields    => [
              :component => 'tabs',
              :name      => 'tabs',
              :fields    => [
                {
                  :component => 'tab-item',
                  :name      => 'default',
                  :title     => _('Default'),
                  :fields    => [
                    {
                      :component              => 'validate-provider-credentials',
                      :name                   => 'endpoints.default.valid',
                      :validationDependencies => %w[name type api_version provider_region keystone_v3_domain_id],
                      :fields                 => [
                        {
                          :component  => "select-field",
                          :name       => "endpoints.default.default_security_protocol",
                          :label      => _("Security Protocol"),
                          :isRequired => true,
                          :validate   => [{:type => "required-validator"}],
                          :options    => [
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
                          :name       => "endpoints.default.default_hostname",
                          :label      => _("Hostname (or IPv4 or IPv6 address)"),
                          :isRequired => true,
                          :validate   => [{:type => "required-validator"}],
                        },
                        {
                          :component    => "text-field",
                          :name         => "endpoints.default.default_api_port",
                          :label        => _("API Port"),
                          :type         => "number",
                          :initialValue => 13_000,
                          :isRequired   => true,
                          :validate     => [{:type => "required-validator"}],
                        },
                        {
                          :component  => "text-field",
                          :name       => "endpoints.default.default_userid",
                          :label      => "Username",
                          :isRequired => true,
                          :validate   => [{:type => "required-validator"}],
                        },
                        {
                          :component  => "text-field",
                          :name       => "endpoints.default.password",
                          :label      => "Password",
                          :type       => "password",
                          :isRequired => true,
                          :validate   => [{:type => "required-validator"}],
                        },
                      ]
                    },
                  ]
                },
                {
                  :component => 'tab-item',
                  :name      => 'events',
                  :title     => _('Events'),
                  :fields    => [
                    {
                      :component    => 'select-field',
                      :name         => 'event_stream_selection',
                      :initialValue => 'ceilometer',
                      :label        => _('Type'),
                      :options      => [
                        {
                          :label => _("Ceilometer"),
                          :value => "ceilometer"
                        },
                        {
                          :label => _("AMQP"),
                          :value => "amqp"
                        }
                      ]
                    },
                    {
                      :component              => 'validate-provider-credentials',
                      :name                   => 'endpoints.amqp.valid',
                      :validationDependencies => %w[type event_stream_selection],
                      :condition              => {
                        :when => 'event_stream_selection',
                        :is   => 'amqp',
                      },
                      :fields                 => [
                        {
                          :component  => "text-field",
                          :name       => "endpoints.amqp.amqp_hostname",
                          :label      => _("Hostname (or IPv4 or IPv6 address)"),
                          :isRequired => true,
                          :validate   => [{:type => "required-validator"}],
                        },
                        {
                          :component    => "text-field",
                          :name         => "endpoints.amqp.amqp_api_port",
                          :label        => _("API Port"),
                          :type         => "number",
                          :isRequired   => true,
                          :initialValue => 5672,
                          :validate     => [{:type => "required-validator"}],
                        },
                        {
                          :component  => "text-field",
                          :name       => "endpoints.amqp.amqp_userid",
                          :label      => "Username",
                          :isRequired => true,
                          :validate   => [{:type => "required-validator"}],
                        },
                        {
                          :component  => "text-field",
                          :name       => "endpoints.amqp.password",
                          :label      => "Password",
                          :type       => "password",
                          :isRequired => true,
                          :validate   => [{:type => "required-validator"}],
                        },
                      ],
                    },
                  ],
                },
                {
                  :component => 'tab-item',
                  :name      => 'rsa',
                  :title     => _('RSA key pair'),
                  :fields    => [
                    {
                      :component => "text-field",
                      :name      => "endpoints.rsa.username",
                      :label     => _("Username"),
                    },
                    {
                      :component => "text-field", # file upload maybe?
                      :name      => "endpoints.rsa.private_key",
                      :label     => _("Private Key"),
                      :type      => "password",
                    },
                  ],
                },
              ],
            ],
          },
        ]
      }
    end

    # Verify Credentials
    #
    # args: {
    #   "name" => String,
    #   "provider_region" => String,
    #   "api_version" => String,
    #   "endpoints" => {
    #     "default" => {
    #       "default_userid" => String,
    #       "default_hostname" => String,
    #       "default_api_port" => Integer,
    #       "default_security_protocol" => String,
    #       "password" => String,
    #     },
    #     "amqp" => {
    #       "amqp_hostname" => String,
    #       "amqp_userid" => String,
    #       "amqp_api_port" => String,
    #       "password" => String,
    #     },
    #   },
    # }
    def verify_credentials(args)
      root_params = %w[name provider_region api_version]
      params = args.sice(root_params).symbolize_keys

      default_endpoint = args.dig("endpoints", "default")
      password = default_endpoint&.dig("password")

      endpoint_params = %w[default_userid default_hostname default_api_port security_protocol]
      params.merge(default_endpoint&.slice(endpoint_params)&.symbolize_keys || {})

      !!raw_connect(password, params)
    end

    def raw_connect(password, params, service = "Compute")
      if params[:event_stream_selection] == 'amqp'
        amqp_available?(password, params)
      else
        ems_connect?(password, params, service)
      end
    end

    def translate_exception(err)
      require 'excon'
      case err
      when Excon::Errors::NotFound
        MiqException::MiqHostError.new("Endpoint not found.")
      when Excon::Errors::Unauthorized
        MiqException::MiqInvalidCredentialsError.new("Login failed due to a bad username or password.")
      when Excon::Errors::Timeout
        MiqException::MiqUnreachableError.new("Login attempt timed out")
      when Excon::Errors::SocketError
        MiqException::MiqHostError.new("Socket error: #{err.message}")
      when MiqException::MiqInvalidCredentialsError, MiqException::MiqHostError, MiqException::ServiceNotAvailable
        err
      else
        MiqException::MiqEVMLoginError.new("Unexpected response returned from system: #{parse_error_message_from_fog_response(err)}")
      end
    end
  end

  def auth_url
    self.class.auth_url(address, port)
  end

  def browser_url
    "http://#{address}/dashboard"
  end

  def openstack_handle(options = {})
    require 'manageiq/providers/openstack/legacy/openstack_handle'
    @openstack_handle ||= begin
      raise MiqException::MiqInvalidCredentialsError, "No credentials defined" if self.missing_credentials?(options[:auth_type])

      username = options[:user] || authentication_userid(options[:auth_type])
      password = options[:pass] || authentication_password(options[:auth_type])

      extra_options = {
        :ssl_ca_file    => ::Settings.ssl.ssl_ca_file,
        :ssl_ca_path    => ::Settings.ssl.ssl_ca_path,
        :ssl_cert_store => OpenSSL::X509::Store.new
      }
      extra_options[:domain_id]         = keystone_v3_domain_id
      extra_options[:region]            = provider_region if provider_region.present?
      extra_options[:omit_default_port] = ::Settings.ems.ems_openstack.excon.omit_default_port
      extra_options[:read_timeout]      = ::Settings.ems.ems_openstack.excon.read_timeout

      osh = OpenstackHandle::Handle.new(username, password, address, port, api_version, security_protocol, extra_options)
      osh.connection_options = {:instrumentor => $fog_log}
      osh
    end
  end

  def reset_openstack_handle
    @openstack_handle = nil
  end

  def connect(options = {})
    openstack_handle(options).connect(options)
  end

  def connect_volume
    connect(:service => "Volume")
  end

  def connect_identity
    connect(:service => "Identity")
  end

  def event_monitor_options
    @event_monitor_options ||= begin
      opts = {:ems => self, :automatic_recovery => false, :recover_from_connection_close => false}

      ceilometer = connection_configuration_by_role("ceilometer")

      if ceilometer.try(:endpoint) && !ceilometer.try(:endpoint).try(:marked_for_destruction?)
        opts[:events_monitor] = :ceilometer
      elsif (amqp = connection_configuration_by_role("amqp"))
        opts[:events_monitor] = :amqp
        if (endpoint = amqp.try(:endpoint))
          opts[:hostname]          = endpoint.hostname
          opts[:port]              = endpoint.port
          opts[:security_protocol] = endpoint.security_protocol
        end

        if (authentication = amqp.try(:authentication))
          opts[:username] = authentication.userid
          opts[:password] = authentication.password
        end

        if (amqp_fallback1_endpoint = connection_configuration_by_role("amqp_fallback1").try(:endpoint))
          opts[:amqp_fallback_hostname1] = amqp_fallback1_endpoint.hostname
        end

        if (amqp_fallback2_endpoint = connection_configuration_by_role("amqp_fallback2").try(:endpoint))
          opts[:amqp_fallback_hostname2] = amqp_fallback2_endpoint.hostname
        end
      end
      opts
    end
  end

  def event_monitor_available?
    require 'manageiq/providers/openstack/legacy/openstack_event_monitor'
    OpenstackEventMonitor.available?(event_monitor_options)
  rescue => e
    _log.error("Exception trying to find openstack event monitor for #{name}(#{hostname}). #{e.message}")
    _log.error(e.backtrace.join("\n"))
    false
  end

  def sync_event_monitor_available?
    event_monitor_options[:events_monitor] == :ceilometer ? authentication_status_ok? : event_monitor_available?
  end

  def stop_event_monitor_queue_on_change
    if event_monitor_class && !self.new_record? && (authentications.detect{ |x| x.previous_changes.present? } ||
                                                    endpoints.detect{ |x| x.previous_changes.present? })
      _log.info("EMS: [#{name}], Credentials or endpoints have changed, stopping Event Monitor. It will be restarted by the WorkerMonitor.")
      stop_event_monitor_queue
      network_manager.stop_event_monitor_queue if try(:network_manager) && !network_manager.new_record?
      cinder_manager.stop_event_monitor_queue if try(:cinder_manager) && !cinder_manager.new_record?
    end
  end

  def stop_event_monitor_queue_on_credential_change
    # TODO(lsmola) this check should not be needed. Right now we are saving each individual authentication and
    # it is breaking the check for changes. We should have it all saved by autosave when saving EMS, so the code
    # for authentications needs to be rewritten.
    stop_event_monitor_queue_on_change
  end

  def translate_exception(err)
    self.class.translate_exception(err)
  end

  def verify_api_credentials(options = {})
    options[:service] = "Compute"
    with_provider_connection(options) {}
    true
  rescue => err
    miq_exception = translate_exception(err)
    raise unless miq_exception

    _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
    raise miq_exception
  end
  private :verify_api_credentials

  def verify_amqp_credentials(_options = {})
    require 'manageiq/providers/openstack/legacy/openstack_event_monitor'
    OpenstackEventMonitor.test_amqp_connection(event_monitor_options)
  rescue => err
    miq_exception = translate_exception(err)
    raise unless miq_exception

    _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
    raise miq_exception
  end
  private :verify_amqp_credentials

  def verify_credentials(auth_type = nil, options = {})
    auth_type ||= 'default'

    raise MiqException::MiqHostError, "No credentials defined" if self.missing_credentials?(auth_type)

    options[:auth_type] = auth_type
    case auth_type.to_s
    when 'default' then verify_api_credentials(options)
    when 'amqp' then    verify_amqp_credentials(options)
    else;           raise "Invalid OpenStack Authentication Type: #{auth_type.inspect}"
    end
  end

  def required_credential_fields(_type)
    [:userid, :password]
  end

  def orchestration_template_validate(template)
    openstack_handle.orchestration_service.templates.validate(:template => template.content)
    nil
  rescue Excon::Errors::BadRequest => bad
    JSON.parse(bad.response.body)['error']['message']
  rescue => err
    _log.error "template=[#{template.name}], error: #{err}"
    raise MiqException::MiqOrchestrationValidationError, err.to_s, err.backtrace
  end

  delegate :description, :to => :class
end

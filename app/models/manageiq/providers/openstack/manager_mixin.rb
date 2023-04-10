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
        :hostname => params[:hostname],
        :username => params[:userid],
        :password => ManageIQ::Password.try_decrypt(password),
        :port     => params[:api_port] || params[:port].to_s
      )
    end
    private :amqp_available?

    def stf_available?(_password, params)
      require 'manageiq/providers/openstack/legacy/events/openstack_stf_event_monitor'
      OpenstackStfEventMonitor.available?(
        :hostname          => params[:hostname],
        :port              => params[:api_port] || params[:port].to_s,
        :security_protocol => params[:security_protocol]
      )
    end
    private :stf_available?

    def ceilometer_available?(password, params)
      ems_connect?(password, params, "Event")
    end
    private :ceilometer_available?

    def ems_connect?(password, params, service)
      ems = new
      ems.name                   = params[:name].strip
      ems.provider_region        = params[:provider_region]
      ems.api_version            = params[:api_version].strip
      ems.security_protocol      = params[:security_protocol].strip
      ems.keystone_v3_domain_id  = params[:uid_ems]

      user, hostname, port = params[:userid], params[:hostname].strip, params[:port]

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

    # Verify Credentials
    #
    # args: {
    #   "name" => String,
    #   "provider_region" => String,
    #   "api_version" => String,
    #   "endpoints" => {
    #     "default" => {
    #       "hostname" => String,
    #       "port" => Integer,
    #       "security_protocol" => String,
    #     },
    #     "amqp" => {
    #       "hostname" => String,
    #       "port" => String,
    #     },
    #     "stf" => {
    #       "hostname" => String,
    #       "port" => String,
    #     },
    #   },
    #   "authentications" => {
    #     "default" =>
    #       "userid" => String,
    #       "password" => String,
    #     }
    #     "amqp" => {
    #       "userid" => String,
    #       "password" => String,
    #     }
    #   }
    # }
    def verify_credentials(args)
      endpoints = args["endpoints"] || {}
      authentications = args["authentications"]

      # ceilometer has no additional endpoint info other than what is in the default endpoint
      # but has to be verified separately
      if args["event_stream_selection"] == "ceilometer"
        endpoints["ceilometer"] = endpoints["default"]
        authentications["ceilometer"] = authentications["default"]
      end

      endpoints.each do |endpoint_name, endpoint|
        authentication = authentications[endpoint_name]

        userid, password = authentication&.values_at('userid', 'password')
        password = ManageIQ::Password.try_decrypt(password)
        password ||= find(args["id"]).authentication_password(endpoint_name) if args["id"]

        endpoint_params = endpoint.slice("hostname", "port", "security_protocol")
        args_params     = args.slice('name', 'provider_region', 'api_version', 'uid_ems')

        params = {
          "userid"   => userid,
          "password" => password
        }.merge(endpoint_params).merge(args_params)

        params['event_stream_selection'] = args['event_stream_selection'] if endpoint_name != 'default'

        raise unless !!raw_connect(password, params.symbolize_keys)
      end
    end

    def raw_connect(password, params, service = "Compute")
      params[:proxy] = openstack_proxy if openstack_proxy

      case params[:event_stream_selection]
      when "amqp"
        amqp_available?(password, params)
      when "stf"
        stf_available?(password, params)
      when "ceilometer"
        ceilometer_available?(password, params)
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
        MiqException::MiqInvalidCredentialsError.new("Login failed.")
      when Excon::Errors::Timeout
        MiqException::MiqUnreachableError.new("Login attempt timed out")
      when Excon::Errors::SocketError
        MiqException::MiqHostError.new("Socket error: #{err.socket_error}")
      when Excon::Error::BadRequest
        MiqException::MiqHostError.new("Bad request: #{err.response.body}")
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
      extra_options[:proxy]             = openstack_proxy if openstack_proxy

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
      stf = connection_configuration_by_role("stf")
      endpoint = stf.try(:endpoint)

      if endpoint
        opts[:events_monitor]    = :stf
        opts[:hostname]          = endpoint.hostname
        opts[:port]              = endpoint.port
        opts[:security_protocol] = endpoint.security_protocol
        # Add auth/credentials when it become supported in OpenStack
      elsif ceilometer.try(:endpoint) && !ceilometer.try(:endpoint).try(:marked_for_destruction?)
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
    verify_event_monitor
  rescue => e
    _log.error("Exception trying to find openstack event monitor for #{name}(#{hostname}). #{e.message}")
    _log.error(e.backtrace.join("\n"))
    false
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

  def verify_event_monitor(_options = {})
    require 'manageiq/providers/openstack/legacy/openstack_event_monitor'
    OpenstackEventMonitor.available?(event_monitor_options)
  rescue => err
    miq_exception = translate_exception(err)
    raise miq_exception || err
  end

  def verify_credentials(auth_type = nil, options = {})
    auth_type ||= 'default'

    raise MiqException::MiqHostError, "No credentials defined" if missing_credentials?(auth_type)

    options[:auth_type] = auth_type
    case auth_type.to_s
    when 'default'     then verify_api_credentials(options)
    when 'amqp'        then verify_amqp_credentials(options)
    when 'ssh_keypair' then verify_ssh_keypair_credentials(options)
    else               raise "Invalid OpenStack Authentication Type: #{auth_type.inspect}"
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

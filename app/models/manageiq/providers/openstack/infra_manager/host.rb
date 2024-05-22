require 'manageiq/providers/openstack/legacy/openstack_configuration_parser'

class ManageIQ::Providers::Openstack::InfraManager::Host < ::Host
  include ManageIQ::Providers::Openstack::HelperMethods
  belongs_to :availability_zone

  has_many :host_service_group_openstacks, :foreign_key => :host_id, :dependent => :destroy,
    :class_name => 'ManageIQ::Providers::Openstack::InfraManager::HostServiceGroup'

  has_many :network_ports, :as => :device
  has_many :cloud_subnets,   :through => :network_ports
  has_many :network_routers, :through => :cloud_subnets
  has_many :cloud_networks,  :through => :cloud_subnets
  alias_method :private_networks, :cloud_networks

  has_many :public_networks, :through => :cloud_subnets

  has_many :floating_ips, :through => :network_ports

  include Operations

  supports :capture
  supports :update
  supports :refresh_network_interfaces
  supports :set_node_maintenance
  supports :unset_node_maintenance
  supports :start do
    _("Cannot start. Already on.") unless state.casecmp("off") == 0
  end
  supports :stop do
    _("Cannot stop. Already off.") unless state.casecmp("on") == 0
  end

  # TODO(lsmola) for some reason UI can't handle joined table cause there is hardcoded somewhere that it selects
  # DISTINCT id, with joined tables, id needs to be prefixed with table name. When this is figured out, replace
  # cloud tenant with rails relations
  # in /app/models/miq_report/search.rb:83 there is select(:id) by hard
  # has_many :vms, :class_name => 'ManageIQ::Providers::Openstack::CloudManager::Vm', :foreign_key => :host_id
  # has_many :cloud_tenants, :through => :vms, :uniq => true

  def cloud_tenants
    ::CloudTenant.where(:id => vms.collect(&:cloud_tenant_id).uniq)
  end

  def ssh_users_and_passwords
    user_auth_key, auth_key = auth_user_keypair
    user_password, password = auth_user_pwd
    su_user, su_password = nil, nil

    # TODO(lsmola) make sudo user work with password. We will not probably support su, as root will not have password
    # allowed. Passwordless sudo is good enough for now

    if !user_auth_key.blank? && !auth_key.blank?
      passwordless_sudo = user_auth_key != 'root'
      return user_auth_key, nil, su_user, su_password, {:key_data => auth_key, :passwordless_sudo => passwordless_sudo}
    else
      passwordless_sudo = user_password != 'root'
      return user_password, password, su_user, su_password, {:passwordless_sudo => passwordless_sudo}
    end
  end

  def get_parent_keypair(type = nil)
    # Get private key defined on Provider level, in the case all hosts has the same user
    ext_management_system.try(:authentication_type, type)
  end

  def authentication_best_fit(requested_type = nil)
    [requested_type, :ssh_keypair, :default].compact.uniq.each do |type|
      auth = authentication_type(type)
      return auth if auth && auth.available?
    end
    # If auth is not defined on this specific host, get auth defined for all hosts from the parent provider.
    get_parent_keypair(:ssh_keypair)
  end

  def authentication_status
    if !authentication_type(:ssh_keypair).try(:auth_key).blank?
      authentication_type(:ssh_keypair).status
    elsif !authentication_type(:default).try(:password).blank?
      authentication_type(:default).status
    else
      # If credentials are not on host's auth, we use host's ssh_keypair as a placeholder for status
      authentication_type(:ssh_keypair).try(:status) || "None"
    end
  end

  def params_for_update
    {
      :fields => [
        {
          :component => 'sub-form',
          :id        => 'endpoints-subform',
          :name      => 'endpoints-subform',
          :title     => _("Endpoints"),
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
                    :component  => 'validate-host-credentials',
                    :id         => 'endpoints.default.valid',
                    :name       => 'endpoints.default.valid',
                    :skipSubmit => true,
                    :isRequired => true,
                    :fields     => [
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
                    ],
                  },
                ],
              },
              {
                :component => 'tab-item',
                :id        => 'remote-tab',
                :name      => 'remote-tab',
                :title     => _('Remote Login'),
                :fields    => [
                  {
                    :component    => 'protocol-selector',
                    :id           => 'remoteEnabled',
                    :name         => 'remoteEnabled',
                    :skipSubmit   => true,
                    :initialValue => 'disabled',
                    :label        => _('Enabled'),
                    :options      => [
                      {
                        :label => _('Disabled'),
                        :value => 'disabled'
                      },
                      {
                        :label => _('Enabled'),
                        :value => 'enabled',
                      },
                    ],
                  },
                  {
                    :component  => 'validate-host-credentials',
                    :id         => 'endpoints.remote.valid',
                    :name       => 'endpoints.remote.valid',
                    :skipSubmit => true,
                    :condition  => {
                      :when => 'remoteEnabled',
                      :is   => 'enabled',
                    },
                    :fields     => [
                      {
                        :component  => "text-field",
                        :id         => "authentications.remote.userid",
                        :name       => "authentications.remote.userid",
                        :label      => _("Username"),
                        :isRequired => true,
                        :validate   => [{:type => "required"}],
                      },
                      {
                        :component  => "password-field",
                        :id         => "authentications.remote.password",
                        :name       => "authentications.remote.password",
                        :label      => _("Password"),
                        :type       => "password",
                        :isRequired => true,
                        :validate   => [{:type => "required"}],
                        :helperText => _('Required if SSH login is disabled for the Default account.')
                      },
                    ],
                  },
                ],
              },
              {
                :component => 'tab-item',
                :id        => 'ssh_keypair-tab',
                :name      => 'ssh_keypair-tab',
                :title     => _('SSH Keypair'),
                :fields    => [
                  {
                    :component    => 'protocol-selector',
                    :id           => 'sshkeypairEnabled',
                    :name         => 'sshkeypairEnabled',
                    :skipSubmit   => true,
                    :initialValue => 'disabled',
                    :label        => _('Enabled'),
                    :options      => [
                      {
                        :label => _('Disabled'),
                        :value => 'disabled'
                      },
                      {
                        :label => _('Enabled'),
                        :value => 'enabled',
                      },
                    ],
                  },
                  {
                    :component  => 'validate-host-credentials',
                    :id         => 'endpoints.ssh_keypair.valid',
                    :name       => 'endpoints.ssh_keypair.valid',
                    :skipSubmit => true,
                    :condition  => {
                      :when => 'sshkeypairEnabled',
                      :is   => 'enabled',
                    },
                    :fields     => [
                      {
                        :component  => "text-field",
                        :id         => "authentications.ssh_keypair.userid",
                        :name       => "authentications.ssh_keypair.userid",
                        :label      => _("Username"),
                        :isRequired => true,
                        :validate   => [{:type => "required"}],
                      },
                      {
                        :component  => "password-field",
                        :id         => "authentications.ssh_keypair.password",
                        :name       => "authentications.ssh_keypair.password",
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
                :id        => 'ws-tab',
                :name      => 'ws-tab',
                :title     => _('Web Service'),
                :fields    => [
                  {
                    :component    => 'protocol-selector',
                    :id           => 'wsEnabled',
                    :name         => 'wsEnabled',
                    :skipSubmit   => true,
                    :initialValue => 'disabled',
                    :label        => _('Enabled'),
                    :options      => [
                      {
                        :label => _('Disabled'),
                        :value => 'disabled'
                      },
                      {
                        :label => _('Enabled'),
                        :value => 'enabled',
                      },
                    ],
                  },
                  {
                    :component  => 'validate-host-credentials',
                    :id         => 'endpoints.ws.valid',
                    :name       => 'endpoints.ws.valid',
                    :skipSubmit => true,
                    :condition  => {
                      :when => 'wsEnabled',
                      :is   => 'enabled',
                    },
                    :fields     => [
                      {
                        :component  => "text-field",
                        :id         => "authentications.ws.userid",
                        :name       => "authentications.ws.userid",
                        :label      => _("Username"),
                        :isRequired => true,
                        :validate   => [{:type => "required"}],
                      },
                      {
                        :component  => "password-field",
                        :id         => "authentications.ws.password",
                        :name       => "authentications.ws.password",
                        :label      => _("Password"),
                        :type       => "password",
                        :isRequired => true,
                        :validate   => [{:type => "required"}],
                        :helperText => _('Used for access to Web Services.')
                      },
                    ],
                  },
                ],
              },
            ]
          ]
        },
      ]
    }
  end

  def update_ssh_auth_status!
    # Creating just Auth status placeholder, the credentials are stored in parent or this auth, parent is
    # EmsOpenstackInfra in this case. We will create Auth per Host where we will store state, if it not exists
    auth = authentication_type(:ssh_keypair) ||
           ManageIQ::Providers::Openstack::InfraManager::AuthKeyPair.create(
             :name          => "#{self.class.name} #{name}",
             :authtype      => :ssh_keypair,
             :resource_id   => id,
             :resource_type => 'Host')

    # If authentication is defined per host, use that
    best_fit_auth = authentication_best_fit
    auth = best_fit_auth if best_fit_auth && !parent_credentials?

    status, details = authentication_check_no_validation(auth.authtype, {})
    status == :valid ? auth.validation_successful : auth.validation_failed(status, details)
  end

  def missing_credentials?(type = nil)
    if type.to_s == "ssh_keypair"
      if !authentication_type(:ssh_keypair).try(:auth_key).blank?
        # Credential are defined on host
        !has_credentials?(type)
      else
        # Credentials are defined on parent ems
        get_parent_keypair(:ssh_keypair).try(:userid).blank?
      end
    else
      !has_credentials?(type)
    end
  end

  def parent_credentials?
    # Whether credentials are defined in parent or host. Missing credentials can be taken as parent.
    authentication_best_fit.try(:resource_type) != 'Host'
  end

  def collect_services(ssu)
    containers = ssu.shell_exec(list_all_service_containers_cmd)
    if containers
      containers = MiqLinux::Utils.parse_docker_ps_list(containers)
      return super(ssu).concat(containers)
    end
    super(ssu)
  end

  def refresh_openstack_services(ssu)
    openstack_status = ssu.shell_exec("systemctl -la --plain | awk '/openstack/ {gsub(/ +/, \" \"); gsub(\".service\", \":\"); gsub(\"not-found\",\"(disabled)\"); split($0,s,\" \"); print s[1],s[3],s[2]}' | sed \"s/ loaded//g\"")
    openstack_containerized_status = ssu.shell_exec(list_all_service_containers_cmd)

    services = MiqLinux::Utils.parse_openstack_status(openstack_status)
    if openstack_containerized_status.present?
      containerized_services = MiqLinux::Utils.parse_openstack_container_status(openstack_containerized_status)
      services = MiqLinux::Utils.merge_openstack_services(services, containerized_services)
    end

    self.host_service_group_openstacks = services.map do |service|
      # find OpenstackHostServiceGroup records by host and name and initialize if not found
      host_service_group_openstacks.where(:name => service['name'])
        .first_or_initialize.tap do |host_service_group_openstack|
        # find SystemService records by host
        # filter SystemService records by names from openstack systemctl status results
        sys_services = system_services.where(:name => service['services'].map { |ser| ser['name'] })
        # associate SystemService record with OpenstackHostServiceGroup
        host_service_group_openstack.system_services = sys_services

        # find Filesystem records by host
        # filter Filesystem records by names
        # we assume that /etc/<service name>* is good enough pattern
        dir_name = "/etc/#{host_service_group_openstack.name.downcase.gsub(/\sservice.*/, '')}"

        matcher = Filesystem.arel_table[:name].matches("#{dir_name}%")
        files = filesystems.where(matcher)
        host_service_group_openstack.filesystems = files

        # save all changes
        host_service_group_openstack.save
        # parse files into attributes
        refresh_custom_attributes_from_conf_files(files) unless files.blank?
      end
    end
  rescue => err
    _log.log_backtrace(err)
    raise err
  end

  def list_all_service_containers_cmd
    'bash -c "if [ -e /usr/bin/podman ]; then sudo podman ps --format \"{{.Names}} {{.Status}}\"; \
    elif [ -e /usr/bin/docker ]; then docker ps --format \"table {{.Names}}\t{{.Status}}\" | tail -n +2; fi"'
  end

  def refresh_custom_attributes_from_conf_files(files)
    # Will parse all conf files and save them to CustomAttribute
    files.select { |x| x.name.include?('.conf') }.each do |file|
      save_custom_attributes(file) if file.contents
    end
  end

  def add_unique_names(file, hashes)
    hashes.each do |x|
      # Adding unique ID for all custom attributes of a host, otherwise drift filters out the non unique ones
      section = x[:section] || ""
      name    = x[:name]    || ""
      x[:unique_name] = "#{file.name}:#{section}:#{name}"
    end
    hashes
  end

  def save_custom_attributes(file)
    hashes = OpenstackConfigurationParser.parse(file.contents)
    hashes = add_unique_names(file, hashes)
    EmsRefresh.save_custom_attributes_inventory(file, hashes, :scan) if hashes
  end

  def disconnect_ems(e = nil)
    self.availability_zone = nil if e.nil? || ext_management_system == e
    super
  end

  def manageable_queue(userid = "system", _options = {})
    task_opts = {
      :action => "Setting node to manageable",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "manageable",
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => my_zone,
      :msg_timeout => ::Settings.host_manageable.queue_timeout.to_i_with_method,
      :args        => []
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def manageable
    connection = ext_management_system.openstack_handle.detect_baremetal_service
    response = connection.set_node_provision_state(name, "manage")

    if response.status == 202
      EmsRefresh.queue_refresh(ext_management_system)
    end
  rescue => e
    _log.error "host=[#{name}], error: #{e}"
    raise MiqException::MiqOpenstackInfraHostSetManageableError, parse_error_message_from_fog_response(e), e.backtrace
  end

  def introspect_queue(userid = "system", _options = {})
    task_opts = {
      :action => "Introspect node",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "introspect",
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => my_zone,
      :msg_timeout => ::Settings.host_introspect.queue_timeout.to_i_with_method,
      :args        => []
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def introspect
    connection = ext_management_system.openstack_handle.detect_workflow_service
    workflow = "tripleo.baremetal.v1.introspect"
    input = { :node_uuids => [name] }
    response = connection.create_execution(workflow, input)
    workflow_state = response.body["state"]
    workflow_execution_id = response.body["id"]

    while workflow_state == "RUNNING"
      sleep 5
      response = connection.get_execution(workflow_execution_id)
      workflow_state = response.body["state"]
    end

    if workflow_state == "SUCCESS"
      EmsRefresh.queue_refresh(ext_management_system)
    end
  rescue => e
    _log.error "host=[#{name}], error: #{e}"
    raise MiqException::MiqOpenstackInfraHostIntrospectError, parse_error_message_from_fog_response(e), e.backtrace
  end

  def provide_queue(userid = "system", _options = {})
    task_opts = {
      :action => "Provide Host (Setting Host to available state)",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "provide",
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => my_zone,
      :msg_timeout => ::Settings.host_provide.queue_timeout.to_i_with_method,
      :args        => []
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def provide
    connection = ext_management_system.openstack_handle.detect_workflow_service
    workflow = "tripleo.baremetal.v1.provide"
    input = { :node_uuids => [name] }
    response = connection.create_execution(workflow, input)
    workflow_state = response.body["state"]
    workflow_execution_id = response.body["id"]

    while workflow_state == "RUNNING"
      sleep 5
      response = connection.get_execution(workflow_execution_id)
      workflow_state = response.body["state"]
    end
    if workflow_state == "SUCCESS"
      EmsRefresh.queue_refresh(ext_management_system)
    end
  rescue => e
    _log.error "host=[#{name}], error: #{e}"
    raise MiqException::MiqOpenstackInfraHostProvideError, parse_error_message_from_fog_response(e), e.backtrace
  end

  def start(userid = "system")
    ironic_set_power_state_queue(userid, "power on")
  end

  def stop(userid = "system")
    ironic_set_power_state_queue(userid, "power off")
  end

  supports :destroy do
    if !archived? && hardware.provision_state == "active"
      "Cannot remove #{name} because it is in #{hardware.provision_state} state."
    end
  end

  def destroy_queue
    destroy_ironic_queue
  end

  def destroy_ironic_queue(userid = "system")
    task_opts = {
      :action => "Deleting Ironic node: #{ems_ref} for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => "destroy_ironic",
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => my_zone,
      :msg_timeout => ::Settings.host_delete.queue_timeout.to_i_with_method,
      :args        => []
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def destroy_ironic
    # Archived node has no associated back end provider; just delete the AR object
    if archived?
      destroy
    else
      connection = ext_management_system.openstack_handle.detect_baremetal_service
      response = connection.delete_node(name)

      if response.status == 204
        Host.destroy_queue(id)
      end
    end
  rescue => e
    _log.error "ironic node=[#{ems_ref}], error: #{e}"
    if archived?
      raise e
    else
      raise MiqException::MiqOpenstackInfraHostDestroyError, parse_error_message_from_fog_response(e), e.backtrace
    end
  end

  def refresh_network_interfaces(ssu)
    smartstate_network_ports = MiqLinux::Utils.parse_network_interface_list(ssu.shell_exec("ip a"))

    neutron_network_ports = network_ports.where(:source => :refresh).each_with_object({}) do |network_port, obj|
      obj[network_port.mac_address] = network_port
    end
    neutron_cloud_subnets = ext_management_system.network_manager.cloud_subnets
    hashes = []

    smartstate_network_ports.each do |network_port|
      existing_network_port = neutron_network_ports[network_port[:mac_address]]
      if existing_network_port.blank?
        cloud_subnets = neutron_cloud_subnets.select do |neutron_cloud_subnet|
          if neutron_cloud_subnet.ip_version == 4
            IPAddr.new(neutron_cloud_subnet.cidr).include?(network_port[:fixed_ip])
          else
            IPAddr.new(neutron_cloud_subnet.cidr).include?(network_port[:fixed_ipv6])
          end
        end

        hashes << {:name          => network_port[:name] || network_port[:mac_address],
                   :type          => "ManageIQ::Providers::Openstack::NetworkManager::NetworkPort",
                   :mac_address   => network_port[:mac_address],
                   :cloud_subnets => cloud_subnets,
                   :device        => self,
                   :fixed_ips     => {:subnet_id     => nil,
                                      :ip_address    => network_port[:fixed_ip],
                                      :ip_address_v6 => network_port[:fixed_ipv6]}}

      elsif existing_network_port.name.blank?
        # Just updating a names of network_ports refreshed from Neutron, rest of attributes
        # is handled in refresh section.
        existing_network_port.update(:name => network_port[:name])
      end
    end
    unless hashes.blank?
      EmsRefresh.save_network_ports_inventory(ext_management_system, hashes, nil, :scan)
    end
  rescue => e
    _log.warn("Error in refreshing network interfaces of host #{id}. Error: #{e.message}")
    _log.warn(e.backtrace.join("\n"))
  end

  def self.display_name(number = 1)
    n_('Host (OpenStack)', 'Hosts (OpenStack)', number)
  end

  def self.post_refresh_ems(ems_id, update_start_time)
    ems = ExtManagementSystem.find(ems_id)
    hosts = ems.hosts.where("created_on >= ?", update_start_time)
    hosts.find_each(&:post_create_actions_queue)
  end

  def post_create_actions_queue
    MiqQueue.submit_job(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => 'post_create_actions'
    )
  end

  def post_create_actions
    update_create_event
  end

  def update_create_event
    create_event = ext_management_system.ems_events.find_by(:host_id    => nil,
                                                            :event_type => "compute.instance.create.end",
                                                            :host_name  => uid_ems)
    create_event&.update!(:host_id => id)
  end
end

class ManageIQ::Providers::Openstack::NetworkManager::NetworkRouter < ::NetworkRouter
  include ManageIQ::Providers::Openstack::HelperMethods
  include ProviderObjectMixin
  include AsyncDeleteMixin

  supports :add_interface

  supports :create

  supports :delete do
    if ext_management_system.nil?
      unsupported_reason_add(:delete, _("The Network Router is not connected to an active %{table}") % {
        :table => ui_lookup(:table => "ext_management_systems")
      })
    end
    if network_ports.any?
      unsupported_reason_add(:delete, _("Unable to delete \"%{name}\" because it has associated ports.") % {
        :name => name
      })
    end
  end

  supports :update do
    if ext_management_system.nil?
      unsupported_reason_add(:update, _("The Network Router is not connected to an active %{table}") % {
        :table => ui_lookup(:table => "ext_management_systems")
      })
    end
  end

  supports :remove_interface

  def self.params_for_create(ems, cloud_network_id)
    if cloud_network_id.nil?
      {
        :fields => [
          {
            :component       => 'select',
            :id              => 'cloud_tenant_id',
            :name            => 'cloud_tenant_id',
            :key             => "id-#{ems.id}",
            :label           => _('Cloud Tenant Placement'),
            :placeholder     => "<#{_('Choose')}>",
            :validateOnMount => true,
            :validate        => [{
              :type    => 'required',
              :message => _('Required'),
            }],
            :isRequired      => true,
            :options         => ems.cloud_tenants.map do |ct|
              {
                :label => ct.name,
                :value => ct.id.to_s,
              }
            end,
            :includeEmpty    => true,
            :clearOnUnmount  => true,
          },
          {
            :component => 'sub-form',
            :title     => _('Router Information'),
            :id        => 'routerInformation',
            :name      => 'routerInformation',
            :fields    => [
              {
                :component       => 'text-field',
                :id              => 'router_name',
                :name            => 'name',
                :label           => _('Router Name'),
                :validateOnMount => true,
                :validate        => [{
                  :type    => 'required',
                  :message => _('Required'),
                }],
                :isRequired      => true,
                :clearOnUnmount  => true,
              },
              {
                :component    => 'switch',
                :id           => 'admin_state_up',
                :name         => 'admin_state_up',
                :label        => _('Administrative State'),
                :onText       => _('Up'),
                :offText      => _('Down'),
                :initialValue => true,
              },
            ]
          },
          {
            :component => 'sub-form',
            :title     => _('External Gateway'),
            :id        => 'externalGateway',
            :name      => 'externalGateway',
            :fields    => [
              {
                :component => 'switch',
                :id        => 'enable',
                :name      => 'enable',
                :label     => _('Enable'),
                :onText    => _('Yes'),
                :offText   => _('No'),
              },
              {
                :component    => 'switch',
                :id           => 'source_nat',
                :name         => 'source_nat',
                :label        => _('Source NAT'),
                :onText       => _('Yes'),
                :offText      => _('No'),
                :condition    => {
                  :when => 'enable',
                  :is   => true,
                },
                :initialValue => true,
              },
              {
                :component      => 'select',
                :id             => 'network',
                :name           => 'network',
                :key            => "network-#{ems.id}",
                :label          => _('Network'),
                :placeholder    => "<#{_('Choose')}>",
                :includeEmpty   => true,
                :clearOnUnmount => true,
                :condition      => {
                  :when => 'enable',
                  :is   => true,
                },
                :options        => ems.cloud_networks.select { |cn| cn.ems_id == ems.id && cn.external_facing == true }.map do |cn|
                  {
                    :label => cn.name,
                    :value => cn.id,
                  }
                end,
              },
            ]
          },
        ]
      }
    else
      {
        :fields => [
          {
            :component      => 'select',
            :id             => 'subnet',
            :name           => 'subnet',
            :key            => "subnet-#{ems.id}",
            :label          => _('Fixed IPs Subnet'),
            :placeholder    => "<#{_('Choose')}>",
            :includeEmpty   => true,
            :clearOnUnmount => true,
            :condition      => {
              :and => [
                {
                  :when => 'enable',
                  :is   => true,
                },
                {
                  :when       => 'network',
                  :isNotEmpty => true
                }
              ]
            },
            :options        => ems.cloud_subnets.select { |cs| cs.cloud_network_id == cloud_network_id.to_i }.map do |cs|
              {
                :label => cs.name,
                :value => cs.id
              }
            end,
          },
        ]
      }
    end
  end

  def params_for_update
    {
      :fields => [
        {
          :component       => 'select',
          :id              => 'cloud_tenant_id',
          :name            => 'cloud_tenant_id',
          :key             => "id-#{ext_management_system.id}",
          :label           => _('Cloud Tenant Placement'),
          :placeholder     => "<#{_('Choose')}>",
          :isRequired      => true,
          :validateOnMount => true,
          :isDisabled      => !!id,
          :options         => ext_management_system.cloud_tenants.map do |ct|
            {
              :label => ct.name,
              :value => ct.id.to_s,
            }
          end,
          :includeEmpty    => true,
          :clearOnUnmount  => true,
        },
        {
          :component => 'sub-form',
          :title     => _('Router Information'),
          :id        => 'routerInformation',
          :name      => 'routerInformation',
          :fields    => [
            {
              :component       => 'text-field',
              :id              => 'router_name',
              :name            => 'name',
              :label           => _('Router Name'),
              :validateOnMount => true,
              :validate        => [{
                :type    => 'required',
                :message => _('Required'),
              }],
              :isRequired      => true,
              :clearOnUnmount  => true,
            },
            {
              :component    => 'switch',
              :id           => 'admin_state_up',
              :name         => 'admin_state_up',
              :label        => _('Administrative State'),
              :onText       => _('Up'),
              :offText      => _('Down'),
              :initialValue => true,
            },
          ]
        },
        {
          :component => 'sub-form',
          :title     => _('External Gateway'),
          :id        => 'externalGateway',
          :name      => 'externalGateway',
          :fields    => [
            {
              :component => 'switch',
              :id        => 'enable',
              :name      => 'enable',
              :label     => _('Enable'),
              :onText    => _('Yes'),
              :offText   => _('No'),
            },
            {
              :component    => 'switch',
              :id           => 'source_nat',
              :name         => 'source_nat',
              :label        => _('Source NAT'),
              :onText       => _('Yes'),
              :offText      => _('No'),
              :condition    => {
                :when => 'enable',
                :is   => true,
              },
              :initialValue => true,
            },
            {
              :component      => 'select',
              :id             => 'network',
              :name           => 'network',
              :key            => "id-#{ext_management_system.id}",
              :label          => _('Network'),
              :placeholder    => "<#{_('Choose')}>",
              :includeEmpty   => true,
              :clearOnUnmount => true,
              :condition      => {
                :when => 'enable',
                :is   => true,
              },
              :options        => ext_management_system.cloud_networks.select { |cn| cn.ems_id == ext_management_system.id && cn.external_facing == true }.map do |cn|
                {
                  :label => cn.name,
                  :value => cn.id,
                }
              end,
            },
          ]
        },
        {
          :component      => 'select',
          :id             => 'subnet',
          :name           => 'subnet',
          :label          => _('Fixed IPs Subnet'),
          :placeholder    => "<#{_('Choose')}>",
          :includeEmpty   => true,
          :clearOnUnmount => true,
          :condition      => {
            :and => [
              {
                :when => 'enable',
                :is   => true,
              },
              {
                :when       => 'network',
                :isNotEmpty => true
              }
            ]
          },
          :options        => ext_management_system.cloud_subnets.select { |cs| cs.cloud_network_id == cloud_network_id.to_i }.map do |cs|
            {
              :label => cs.name,
              :value => cs.ems_ref,
            }
          end,
        },
      ]
    }
  end

  def self.raw_create_network_router(ext_management_system, options)
    cloud_tenant = options.delete(:cloud_tenant)
    name = options.delete(:name)
    router = nil

    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      router = service.create_router(name, options).body
    end
    {:ems_ref => router['id'], :name => options[:name]}
  rescue => e
    _log.error "router=[#{options[:name]}], error: #{e}"
    parsed_error = parse_error_message_from_neutron_response(e)
    error_message = case parsed_error
                    when /Quota exceeded for resources/
                      _("Quota exceeded for routers.")
                    else
                      parsed_error
                    end
    raise MiqException::MiqNetworkRouterCreateError, error_message, e.backtrace
  end

  def raw_delete_network_router
    with_notification(:network_router_delete,
                      :options => {
                        :subject => self,
                      }) do
      ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
        service.delete_router(ems_ref)
      end
    end
  rescue => e
    _log.error "router=[#{name}], error: #{e}"
    raise MiqException::MiqNetworkRouterDeleteError, parse_error_message_from_neutron_response(e), e.backtrace
  end

  def delete_network_router_queue(userid)
    task_opts = {
      :action => "deleting Network Router for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'raw_delete_network_router',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => []
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def raw_update_network_router(options)
    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      service.update_router(ems_ref, options)
    end
  rescue => e
    _log.error "router=[#{name}], error: #{e}"
    raise MiqException::MiqNetworkRouterUpdateError, parse_error_message_from_neutron_response(e), e.backtrace
  end

  def update_network_router_queue(userid, options = {})
    task_opts = {
      :action => "updating Network Router for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'raw_update_network_router',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def raw_add_interface(cloud_subnet_id)
    raise ArgumentError, _("Subnet ID cannot be nil") if cloud_subnet_id.nil?
    subnet = CloudSubnet.find(cloud_subnet_id)
    raise ArgumentError, _("Subnet cannot be found") if subnet.nil?

    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      service.add_router_interface(ems_ref, subnet.ems_ref)
    end
  rescue => e
    _log.error "router=[#{name}], error: #{e}"
    raise MiqException::MiqNetworkRouterAddInterfaceError, parse_error_message_from_neutron_response(e), e.backtrace
  end

  def add_interface_queue(userid, cloud_subnet)
    task_opts = {
      :action => "Adding Interface to Network Router for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'raw_add_interface',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [cloud_subnet.id]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def raw_remove_interface(cloud_subnet_id)
    raise ArgumentError, _("Subnet ID cannot be nil") if cloud_subnet_id.nil?
    subnet = CloudSubnet.find(cloud_subnet_id)
    raise ArgumentError, _("Subnet cannot be found") if subnet.nil?

    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      service.remove_router_interface(ems_ref, subnet.ems_ref)
    end
  rescue => e
    _log.error "router=[#{name}], error: #{e}"
    raise MiqException::MiqNetworkRouterRemoveInterfaceError, parse_error_message_from_neutron_response(e), e.backtrace
  end

  def remove_interface_queue(userid, cloud_subnet)
    task_opts = {
      :action => "Removing Interface from Network Router for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'raw_remove_interface',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [cloud_subnet.id]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.connection_options(cloud_tenant = nil)
    connection_options = {:service => "Network"}
    connection_options[:tenant_name] = cloud_tenant.name if cloud_tenant
    connection_options
  end

  def self.display_name(number = 1)
    n_('Network Router (OpenStack)', 'Network Routers (OpenStack)', number)
  end

  private

  def connection_options(cloud_tenant = nil)
    self.class.connection_options(cloud_tenant)
  end
end

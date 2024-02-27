class ManageIQ::Providers::Openstack::NetworkManager::FloatingIp < ::FloatingIp
  include ManageIQ::Providers::Openstack::HelperMethods
  include ProviderObjectMixin
  include AsyncDeleteMixin

  supports :create

  supports :delete do
    if ext_management_system.nil?
      _("The Floating Ip is not connected to an active %{table}") % {
        :table => ui_lookup(:table => "ext_management_systems")
      }
    end
  end

  supports :update do
    if ext_management_system.nil?
      _("The Floating Ip is not connected to an active %{table}") % {
        :table => ui_lookup(:table => "ext_management_systems")
      }
    end
  end

  def self.params_for_create(ems)
    {
      :fields => [
        {
          :component       => 'select',
          :id              => 'cloud_network_id',
          :name            => 'cloud_network_id',
          :label           => _('External Network'),
          :placeholder     => "<#{_('Choose')}>",
          :validateOnMount => true,
          :validate        => [{
            :type    => 'required',
            :message => _('Required'),
          }],
          :options         => ems.public_networks.map do |ct|
            {
              :label => ct.name,
              :value => ct.id.to_s,
            }
          end,
          :includeEmpty    => true,
          :clearOnUnmount  => true,
        },
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
          :title     => _('Association Information'),
          :id        => 'assocation-information',
          :name      => 'assocation-information',
          :fields    => [
            {
              :component       => 'text-field',
              :id              => 'address',
              :name            => 'address',
              :validateOnMount => true,
              :label           => _('Floating IP Address (optional)'),
            },
            {
              :component       => 'text-field',
              :id              => 'fixed_ip_address',
              :name            => 'fixed_ip_address',
              :validateOnMount => true,
              :label           => _('Fixed IP Address'),
            },
            {
              :component       => 'text-field',
              :id              => 'network_port_ems_ref',
              :name            => 'network_port_ems_ref',
              :validateOnMount => true,
              :label           => _('Associated Port ID (blank to disassociate)'),
            }
          ]
        },
      ]
    }
  end

  def params_for_update
    {
      :component => 'sub-form',
      :id        => 'placement',
      :name      => 'placement',
      :fields    => [
        {
          :component       => 'select',
          :id              => 'cloud_network_id',
          :name            => 'cloud_network_id',
          :label           => _('External Network'),
          :placeholder     => "<#{_('Choose')}>",
          :validateOnMount => true,
          :validate        => [{
            :type    => 'required',
            :message => _('Required'),
          }],
          :isDisabled      => !!id,
          :options         => ext_management_system.public_networks.map do |ct|
            {
              :label => ct.name,
              :value => ct.id.to_s,
            }
          end,
          :includeEmpty    => true,
          :clearOnUnmount  => true,
        },
        {
          :component       => 'select',
          :id              => 'cloud_tenant_id',
          :name            => 'cloud_tenant_id',
          :key             => "id-#{ems_id}",
          :label           => _('Cloud Tenant Placement'),
          :placeholder     => "<#{_('Choose')}>",
          :validateOnMount => true,
          :validate        => [{
            :type    => 'required',
            :message => _('Required'),
          }],
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
          :title     => _('Association Information'),
          :id        => 'assocation-information',
          :name      => 'assocation-information',
          :fields    => [
            {
              :component       => 'text-field',
              :id              => 'address',
              :name            => 'address',
              :validateOnMount => true,
              :label           => _('Floating IP Address (optional)'),
            },
            {
              :component       => 'text-field',
              :id              => 'fixed_ip_address',
              :name            => 'fixed_ip_address',
              :validateOnMount => true,
              :label           => _('Fixed IP Address'),
            },
            {
              :component       => 'text-field',
              :id              => 'network_port_ems_ref',
              :name            => 'network_port_ems_ref',
              :validateOnMount => true,
              :label           => _('Associated Port ID (blank to disassociate)'),
            }
          ]
        },
      ]
    }
  end

  def self.raw_create_floating_ip(ext_management_system, options)
    cloud_tenant = options.delete(:cloud_tenant)
    floating_ip = nil
    floating_network_id = CloudNetwork.find(options[:cloud_network_id]).ems_ref

    raw_options = remapping(options)
    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      floating_ip = service.create_floating_ip(floating_network_id, raw_options)
    end
    {:ems_ref => floating_ip['id'], :name => options[:floating_ip_address]}
  rescue => e
    _log.error "floating_ip=[#{options[:floating_ip_address]}], error: #{e}"
    raise MiqException::MiqFloatingIpCreateError, parse_error_message_from_neutron_response(e), e.backtrace
  end

  def self.remapping(options)
    new_options = options.dup
    new_options[:floating_ip_address] = options[:address] if options[:address]
    new_options[:tenant_id] = CloudTenant.find(options[:cloud_tenant_id]).ems_ref if options[:cloud_tenant_id]
    new_options[:port_id] = options[:network_port_ems_ref] if options[:network_port_ems_ref]

    # if we got an empty string or nil for floating_ip_address (probably from the UI form)
    # then remove the parameter from the options because otherwise Neutron will balk about the IP
    # being invalid.
    new_options.delete(:floating_ip_address) if new_options[:floating_ip_address].blank?

    new_options.delete(:address)
    new_options.delete(:cloud_network_id)
    new_options.delete(:network_port_ems_ref)
    new_options.delete(:cloud_tenant_id)
    new_options
  end

  def raw_delete_floating_ip
    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      service.delete_floating_ip(ems_ref)
    end
  rescue => e
    _log.error "floating_ip=[#{name}], error: #{e}"
    raise MiqException::MiqFloatingIpDeleteError, parse_error_message_from_neutron_response(e), e.backtrace
  end

  def delete_floating_ip_queue(userid)
    task_opts = {
      :action => "deleting Floating IP for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'raw_delete_floating_ip',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => []
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def raw_update_floating_ip(options)
    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      if options[:network_port_ems_ref].empty?
        service.disassociate_floating_ip(ems_ref)
      else
        service.associate_floating_ip(ems_ref, options[:network_port_ems_ref])
      end
    end
  rescue => e
    _log.error "floating_ip=[#{name}], error: #{e}"
    raise MiqException::MiqFloatingIpUpdateError, parse_error_message_from_neutron_response(e), e.backtrace
  end

  def update_floating_ip_queue(userid, options = {})
    task_opts = {
      :action => "updating Floating IP for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'raw_update_floating_ip',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.connection_options(cloud_tenant = nil)
    connection_options = {:service => "Network"}
    connection_options[:tenant_name] = cloud_tenant.name if cloud_tenant
    connection_options
  end

  def self.display_name(number = 1)
    n_('Floating IP (OpenStack)', 'Floating IPs (OpenStack)', number)
  end

  private

  def connection_options(cloud_tenant = nil)
    self.class.connection_options(cloud_tenant)
  end
end

class ManageIQ::Providers::Openstack::NetworkManager::SecurityGroup < ::SecurityGroup
  include ManageIQ::Providers::Openstack::HelperMethods

  supports :create

  supports :delete do
    if ext_management_system.nil?
      _("The Security Group is not connected to an active %{table}") % {
        :table => ui_lookup(:table => "ext_management_systems")
      }
    end
  end

  supports :update do
    if ext_management_system.nil?
      _("The Security Group is not connected to an active %{table}") % {
        :table => ui_lookup(:table => "ext_management_systems")
      }
    end
  end

  def self.params_for_create(ems)
    {
      :fields => [
        {
          :component => 'sub-form',
          :title     => _('Security Group Information'),
          :id        => 'security_group_information',
          :name      => 'security_group_information',
          :fields    => [
            {
              :component       => 'text-field',
              :id              => 'security_group_name',
              :name            => 'name',
              :label           => _('Security Group Name'),
              :validateOnMount => true,
              :validate        => [{
                :type    => 'required',
                :message => _('Required'),
              }],
              :isRequired      => true,
              :clearOnUnmount  => true,
            },
            {
              :component => 'text-field',
              :id        => 'security_group_description',
              :name      => 'description',
              :label     => _('Security Group Description'),
            },
          ]
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
          :isRequired      => true,
          :options         => ems.cloud_tenants.map do |ct|
            {
              :label => ct.name,
              :value => ct.id.to_s,
            }
          end,
          :includeEmpty    => true,
          :clearOnUnmount  => true,
        }
      ]
    }
  end

  def params_for_update
    {
      :fields => [
        {
          :component => 'sub-form',
          :title     => _('Security Group Information'),
          :id        => 'security_group_information',
          :name      => 'security_group_information',
          :fields    => [
            {
              :component       => 'text-field',
              :id              => 'security_group_name',
              :name            => 'name',
              :label           => _('Security Group Name'),
              :validateOnMount => true,
              :validate        => [{
                :type    => 'required',
                :message => _('Required'),
              }],
              :isRequired      => true,
              :clearOnUnmount  => true,
            },
            {
              :component => 'text-field',
              :id        => 'security_group_description',
              :name      => 'description',
              :label     => _('Security Group Description'),
            },
          ]
        },
        {
          :component       => 'select',
          :id              => 'cloud_tenant.id',
          :name            => 'cloud_tenant.id',
          :key             => "id-#{ext_management_system.id}",
          :label           => _('Cloud Tenant Placement'),
          :placeholder     => "<#{_('Choose')}>",
          :validateOnMount => true,
          :isDisabled      => !!id,
          :validate        => [{
            :type    => 'required',
            :message => _('Required'),
          }],
          :isRequired      => true,
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
          :id        => 'firewall_rules',
          :name      => 'firewall_rules',
          :fields    => [
            {
              :component         => 'field-array',
              :name              => 'firewall_rules',
              :id                => 'firewall_rules',
              :class_name        => 'firewall',
              :label             => _('Firewall Rules'),
              :noItemsMessage    => _('None'),
              :buttonLabels      => {
                :add    => _('Add a Firewall Rule'),
                :remove => _('Delete'),
              },
              :AddButtonProps    => {
                :size => 'small',
              },
              :RemoveButtonProps => {
                :size => 'small',
              },
              :fields            => [
                {
                  :component    => 'select',
                  :name         => 'direction',
                  :id           => 'direction',
                  :label        => _('Direction'),
                  :includeEmpty => true,
                  :options      => [
                    {
                      :label => _('inbound'),
                      :value => 'inbound',
                    },
                    {
                      :label => _('outbound'),
                      :value => 'outbound',
                    }
                  ]
                },
                {
                  :component    => 'select',
                  :name         => 'network_protocol',
                  :id           => 'network_protocol',
                  :label        => _('Network Protocol'),
                  :includeEmpty => true,
                  :options      => [
                    {
                      :label => _('IPV4'),
                      :value => 'IPV4',
                    },
                    {
                      :label => _('IPV6'),
                      :value => 'IPV6',
                    }
                  ]
                },
                {
                  :component    => 'select',
                  :name         => 'host_protocol',
                  :id           => 'host_protocol',
                  :label        => _('Host Protocol'),
                  :includeEmpty => true,
                  :options      => [
                    {
                      :label => _('TCP'),
                      :value => 'TCP',
                    },
                    {
                      :label => _('UDP'),
                      :value => 'UDP',
                    },
                    {
                      :label => _('ICMP'),
                      :value => 'ICMP',
                    },
                  ]
                },
                {
                  :component    => 'select',
                  :name         => 'source_security_group_id',
                  :id           => 'source_security_group_id',
                  :label        => _('Remote Security Group (name - ref)'),
                  :includeEmpty => true,
                  :options      => ext_management_system.security_groups.map do |sg|
                    {
                      :label => "#{sg.name} - #{sg.ems_ref}",
                      :value => sg.id.to_s,
                    }
                  end
                },
                {
                  :component => 'text-field',
                  :name      => 'source_ip_range',
                  :id        => 'source_ip_range',
                  :label     => _('IP Range'),
                },
                {
                  :component => 'text-field',
                  :name      => 'port',
                  :id        => 'port',
                  :label     => _('Port'),
                },
                {
                  :component => 'text-field',
                  :name      => 'end_port',
                  :id        => 'end_port',
                  :label     => _('End Port'),
                }
              ],
            },
          ]
        },
      ]
    }
  end

  def self.parse_security_group_rule(rule)
    if rule["source_security_group_id"] && !rule["source_security_group_id"].empty?
      sg = SecurityGroup.find(rule["source_security_group_id"])
    end
    {
      :ethertype        => rule["network_protocol"].to_s.downcase,
      :port_range_min   => rule["port"],
      :port_range_max   => rule["end_port"],
      :protocol         => rule["host_protocol"].to_s.downcase,
      :remote_group_id  => sg.try(:ems_ref),
      :remote_ip_prefix => rule["source_ip_range"]
    }
  end

  def self.raw_create_security_group(ext_management_system, options)
    cloud_tenant = options.delete(:cloud_tenant)
    security_group = nil
    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      security_group = service.create_security_group(options).body
    end
  rescue => e
    _log.error "security_group=[#{options[:name]}], error: #{e}"
    raise MiqException::MiqSecurityGroupCreateError, parse_error_message_from_neutron_response(e), e.backtrace
  end

  def raw_delete_security_group
    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      service.delete_security_group(ems_ref)
    end
  rescue => e
    _log.error "security_group=[#{name}], error: #{e}"
    raise MiqException::MiqSecurityGroupDeleteError, parse_error_message_from_neutron_response(e), e.backtrace
  end

  def create_security_group_rule_queue(userid, security_group_id, direction, options = {})
    task_opts = {
      :action => "create Security Group rule for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'raw_create_security_group_rule',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [security_group_id, direction, options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def delete_security_group_queue(userid)
    task_opts = {
      :action => "deleting Security Group for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'raw_delete_security_group',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => []
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def delete_security_group_rule_queue(userid, key)
    task_opts = {
      :action => "delete Security Group rule for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'raw_delete_security_group_rule',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [key]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def raw_create_security_group_rule(security_group_id, direction, options)
    options.delete_if { |_k, v| v.nil? || v.empty? }
    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      service.create_security_group_rule(security_group_id, parse_direction(direction), options)
    end
  rescue => e
    _log.error "security_group=[#{name}], error: #{e}"
    raise MiqException::MiqSecurityGroupCreateError, parse_error_message_from_neutron_response(e), e.backtrace
  end

  def raw_delete_security_group_rule(key)
    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      service.delete_security_group_rule(key)
    end
  rescue => e
    _log.error "security_group=[#{name}], error: #{e}"
    raise MiqException::MiqSecurityGroupDeleteError, parse_error_message_from_neutron_response(e), e.backtrace
  end

  def raw_update_security_group(options)
    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      service.update_security_group(ems_ref, options)
    end
  rescue => e
    _log.error "security_group=[#{name}], error: #{e}"
    raise MiqException::MiqSecurityGroupUpdateError, parse_error_message_from_neutron_response(e), e.backtrace
  end

  def update_security_group_queue(userid, options = {})
    task_opts = {
      :action => "updating Security Group for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'raw_update_security_group',
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
    n_('Security Group (OpenStack)', 'Security Groups (OpenStack)', number)
  end

  private

  def parse_direction(val)
    val == "outbound" ? "egress" : "ingress"
  end

  def connection_options(cloud_tenant = nil)
    self.class.connection_options(cloud_tenant)
  end
end

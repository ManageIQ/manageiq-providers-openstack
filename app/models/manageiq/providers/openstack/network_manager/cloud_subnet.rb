class ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet < ::CloudSubnet
  include ManageIQ::Providers::Openstack::HelperMethods
  include ProviderObjectMixin
  include SupportsFeatureMixin

  supports :create
  supports :delete do
    if ext_management_system.nil?
      _("The subnet is not connected to an active %{table}") % {
        :table => ui_lookup(:table => "ext_management_systems")
      }
    elsif number_of(:vms) > 0
      _("The subnet has an active %{table}") % {
        :table => ui_lookup(:table => "vm_cloud")
      }
    end
  end
  supports :update do
    if ext_management_system.nil?
      _("The subnet is not connected to an active %{table}") % {
        :table => ui_lookup(:table => "ext_management_systems")
      }
    end
  end

  def self.params_for_create(ems)
    {
      :fields => [
        {
          :component    => 'select',
          :name         => 'cloud_tenant_id',
          :id           => 'cloud_tenant_id',
          :label        => _('Cloud Tenant Placement'),
          :validate     => [{:type => 'required'}],
          :includeEmpty => true,
          :isRequired   => true,
          :options      => ems.cloud_tenants.map do |ct|
            {
              :label => ct.name,
              :value => ct.id.to_s,
            }
          end,
        },
        {
          :component    => 'select',
          :name         => 'cloud_network_id',
          :id           => 'cloud_network_id',
          :label        => _('Network'),
          :isRequired   => true,
          :includeEmpty => true,
          :validate     => [{:type => 'required'}],
          :options      => ems.cloud_networks.map do |cvt|
            {
              :label => cvt.name,
              :value => cvt.id.to_s,
            }
          end
        },
        {
          :component => 'text-field',
          :id        => 'gateway',
          :name      => 'gateway',
          :label     => _('Gateway'),
        },
        {
          :component => 'switch',
          :id        => 'dhcp_enabled',
          :name      => 'dhcp_enabled',
          :label     => _('DHCP'),
          :onText    => 'Enabled',
          :offText   => 'Disabled',
        },
        {
          :component => 'select',
          :name      => 'extra_attributes.ip_version',
          :id        => 'extra_attributes.ip_version',
          :label     => _('IP Version'),
          :options   => [
            {
              :label => 'ipv4',
              :value => 4,
            },
            {
              :label => 'ipv6',
              :value => 6,
            }
          ]
        },
        {
          :component         => 'field-array',
          :id                => 'extra_attributes.allocation_pools',
          :name              => 'extra_attributes.allocation_pools',
          :label             => _('Allocation Pools'),
          :fields            => [
            {:component => 'text-field', :id => 'start', :name => 'start', :label => _('Start')},
            {:component => 'text-field', :id => 'end', :name => 'end', :label => _('End')}
          ],
          :noItemsMessage    => _('None'),
          :buttonLabels      => {
            :add    => _('Add'),
            :remove => _('Remove'),
          },
          :AddButtonProps    => {:size => 'small'},
          :RemoveButtonProps => {:size => 'small'},
        },
        {
          :component         => 'field-array',
          :id                => 'extra_attributes.host_routes',
          :name              => 'extra_attributes.host_routes',
          :label             => _('Host Routes'),
          :fields            => [
            {:component => 'text-field', :id => 'nexthop', :name => 'nexthop', :label => _('Nexthop')},
            {:component => 'text-field', :id => 'destination', :name => 'destination', :label => _('Destination')}
          ],
          :noItemsMessage    => _('None'),
          :buttonLabels      => {
            :add    => _('Add'),
            :remove => _('Remove'),
          },
          :AddButtonProps    => {:size => 'small'},
          :RemoveButtonProps => {:size => 'small'},
        },
      ]
    }
  end

  def params_for_update
    {
      :fields => [
        {
          :component    => 'select',
          :name         => 'cloud_tenant_id',
          :id           => 'cloud_tenant_id',
          :label        => _('Cloud Tenant Placement'),
          :validate     => [{:type => 'required'}],
          :includeEmpty => true,
          :isRequired   => true,
          :isDisabled   => true,
          :options      => ext_management_system.cloud_tenants.map do |ct|
            {
              :label => ct.name,
              :value => ct.id,
            }
          end,
        },
        {
          :component    => 'select',
          :name         => 'cloud_network_id',
          :id           => 'cloud_network_id',
          :label        => _('Network'),
          :isRequired   => true,
          :includeEmpty => true,
          :isDisabled   => true,
          :validate     => [{:type => 'required'}],
          :options      => ext_management_system.cloud_networks.map do |cvt|
            {
              :label => cvt.name,
              :value => cvt.id,
            }
          end
        },
        {
          :component => 'text-field',
          :id        => 'gateway',
          :name      => 'gateway',
          :label     => _('Gateway'),
        },
        {
          :component => 'switch',
          :id        => 'dhcp_enabled',
          :name      => 'dhcp_enabled',
          :label     => _('DHCP'),
          :onText    => 'Enabled',
          :offText   => 'Disabled',
        },
        {
          :component  => 'select',
          :name       => 'extra_attributes.ip_version',
          :id         => 'extra_attributes.ip_version',
          :label      => _('IP Version'),
          :isDisabled => true,
          :options    => [
            {
              :label => 'ipv4',
              :value => 4,
            },
            {
              :label => 'ipv6',
              :value => 6,
            }
          ]
        },
        {
          :component         => 'field-array',
          :id                => 'extra_attributes.allocation_pools',
          :name              => 'extra_attributes.allocation_pools',
          :label             => _('Allocation Pools'),
          :fields            => [
            {:component => 'text-field', :id => 'start', :name => 'start', :label => _('Start')},
            {:component => 'text-field', :id => 'end', :name => 'end', :label => _('End')}
          ],
          :noItemsMessage    => _('None'),
          :buttonLabels      => {
            :add    => _('Add'),
            :remove => _('Remove'),
          },
          :AddButtonProps    => {:size => 'small'},
          :RemoveButtonProps => {:size => 'small'},
        },
        {
          :component         => 'field-array',
          :id                => 'extra_attributes.host_routes',
          :name              => 'extra_attributes.host_routes',
          :label             => _('Host Routes'),
          :fields            => [
            {:component => 'text-field', :id => 'nexthop', :name => 'nexthop', :label => _('Nexthop')},
            {:component => 'text-field', :id => 'destination', :name => 'destination', :label => _('Destination')}
          ],
          :noItemsMessage    => _('None'),
          :buttonLabels      => {
            :add    => _('Add'),
            :remove => _('Remove'),
          },
          :AddButtonProps    => {:size => 'small'},
          :RemoveButtonProps => {:size => 'small'},
        },
      ]
    }
  end

  def self.raw_create_cloud_subnet(ext_management_system, options)
    cloud_network_id = options.delete(:cloud_network_id)
    cloud_network = CloudNetwork.find_by(:id => cloud_network_id) if cloud_network_id
    options[:network_id] = cloud_network&.ems_ref
    cloud_tenant_id = options.delete(:cloud_tenant_id)
    cloud_tenant = CloudTenant.find_by(:id => cloud_tenant_id) if cloud_tenant_id
    subnet = nil

    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      subnet = service.subnets.new(options)
      subnet.save
    end
    {:ems_ref => subnet.id, :name => options[:name]}
  rescue => e
    _log.error "subnet=[#{options[:name]}], error: #{e}"
    raise MiqException::MiqCloudSubnetCreateError, parse_error_message_from_neutron_response(e), e.backtrace
  end

  def raw_delete_cloud_subnet
    with_notification(:cloud_subnet_delete,
                      :options => {
                        :subject => self,
                      }) do
      ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
        service.delete_subnet(ems_ref)
      end
    end
  rescue => e
    _log.error "subnet=[#{name}], error: #{e}"
    raise MiqException::MiqCloudSubnetDeleteError, parse_error_message_from_neutron_response(e), e.backtrace
  end

  def raw_update_cloud_subnet(options)
    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      service.update_subnet(ems_ref, options)
    end
  rescue => e
    _log.error "subnet=[#{name}], error: #{e}"
    raise MiqException::MiqCloudSubnetUpdateError, parse_error_message_from_neutron_response(e), e.backtrace
  end

  def update_cloud_subnet_queue(userid, options = {})
    task_opts = {
      :action => "updating Cloud Subnet for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'raw_update_cloud_subnet',
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
    n_('Cloud Subnet (OpenStack)', 'Cloud Subnets (OpenStack)', number)
  end

  private

  def connection_options(cloud_tenant = nil)
    self.class.connection_options(cloud_tenant)
  end
end

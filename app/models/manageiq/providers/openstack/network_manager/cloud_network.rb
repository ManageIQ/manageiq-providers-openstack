require 'uri'
require 'net/http'

class ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork < ::CloudNetwork
  include ManageIQ::Providers::Openstack::HelperMethods
  include SupportsFeatureMixin

  supports :create

  supports :delete do
    if ext_management_system.nil?
      _("The Cloud Network is not connected to an active %{table}") % {
        :table => ui_lookup(:table => "ext_management_systems")
      }
    end
  end

  supports :update do
    if ext_management_system.nil?
      _("The Cloud Network is not connected to an active %{table}") % {
        :table => ui_lookup(:table => "ext_management_systems")
      }
    end
  end

  def self.params_for_create(ems)
    {
      :fields => [
        {
          :component => 'sub-form',
          :title     => _('Placement'),
          :id        => 'placement',
          :name      => 'placement',
          :fields    => [
            {
              :component       => 'select',
              :id              => 'cloud_tenant',
              :name            => 'cloud_tenant',
              :key             => "id-#{ems.id}",
              :label           => _('Cloud Tenant'),
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
          ]
        },
        {
          :component => 'sub-form',
          :title     => _('Network Provider Information'),
          :id        => 'provider-information',
          :name      => 'provider-information',
          :condition => {
            :when       => 'cloud_tenant',
            :isNotEmpty => true,
          },
          :fields    => [
            {
              :component   => 'select',
              :id          => 'provider_network_type',
              :name        => 'provider_network_type',
              :label       => _('Provider Network Type'),
              :placeholder => _('Nothing selected'),
              :options     => [
                {:label => _('None')},
                {:label => _('Local'),  :value => 'local'},
                {:label => _('Flat'),   :value => 'flat'},
                {:label => _('GRE'),    :value => 'gre'},
                {:label => _('GENEVE'), :value => 'geneve'},
                {:label => _('VLAN'),   :value => 'vlan'},
                {:label => _('VXLAN'),  :value => 'vxlan'}
              ],
            },
            {
              :component => 'sub-form',
              :id        => 'subform-1',
              :name      => 'subform-1',
              :condition => {
                :when => 'provider_network_type',
                :is   => 'flat',
              },
              :fields    => [
                {
                  :component       => 'text-field',
                  :label           => _('Physical Network'),
                  :maxLength       => 128,
                  :id              => 'provider_physical_network',
                  :name            => 'provider_physical_network',
                  :validateOnMount => true,
                  :clearOnUnmount  => true,
                  :validate        => [{
                    :type    => 'required',
                    :message => _('Required'),
                  }],
                },
              ],
            },
            {
              :component => 'sub-form',
              :id        => 'subform-2',
              :name      => 'subform-2',
              :condition => {
                :when => 'provider_network_type',
                :is   => 'gre',
              },
              :fields    => [
                {
                  :component       => 'text-field',
                  :label           => _('Segmentation ID'),
                  :maxLength       => 128,
                  :id              => 'provider_segmentation_id',
                  :name            => 'provider_segmentation_id',
                  :validateOnMount => true,
                  :clearOnUnmount  => true,
                  :validate        => [{
                    :type    => 'required',
                    :message => _('Required'),
                  }],
                }
              ]
            },
            {
              :component => 'sub-form',
              :id        => 'subform-3',
              :name      => 'subform-3',
              :condition => {
                :when => 'provider_network_type',
                :is   => 'vlan',
              },
              :fields    => [
                {
                  :component       => 'text-field',
                  :label           => _('Physical Network'),
                  :maxLength       => 128,
                  :id              => 'provider_physical_network',
                  :name            => 'provider_physical_network',
                  :validateOnMount => true,
                  :clearOnUnmount  => true,
                  :validate        => [{
                    :type    => 'required',
                    :message => _('Required'),
                  }],
                },
                {
                  :component       => 'text-field',
                  :label           => _('Segmentation ID'),
                  :maxLength       => 128,
                  :id              => 'provider_segmentation_id',
                  :name            => 'provider_segmentation_id',
                  :validateOnMount => true,
                  :clearOnUnmount  => true,
                  :validate        => [{
                    :type    => 'required',
                    :message => _('Required'),
                  }],
                }
              ]
            },
            {
              :component => 'sub-form',
              :id        => 'subform-4',
              :name      => 'subform-4',
              :condition => {
                :when => 'provider_network_type',
                :is   => 'vxlan',
              },
              :fields    => [
                {
                  :component      => 'text-field',
                  :label          => _('Segmentation ID'),
                  :maxLength      => 128,
                  :id             => 'provider_segmentation_id',
                  :name           => 'provider_segmentation_id',
                  :clearOnUnmount => true,
                }
              ]
            }
          ],
        },
        {
          :component => 'sub-form',
          :title     => _('Network Information'),
          :id        => 'network-information',
          :name      => 'network-information',
          :fields    => [
            {
              :component       => 'text-field',
              :id              => 'name',
              :name            => 'name',
              :validateOnMount => true,
              :label           => _('Network Name'),
              :validate        => [
                {
                  :type    => 'required',
                  :message => _('Required'),
                }
              ]
            }
          ]
        },
        {
          :component => 'switch',
          :id        => 'cloud_network_external_facing',
          :name      => 'external_facing',
          :label     => _('External Router'),
          :onText    => _('Yes'),
          :offText   => _('No'),
        },
        {
          :component => 'switch',
          :id        => 'cloud_network_enabled',
          :name      => 'enabled',
          :label     => _('Adminstrative State'),
          :onText    => _('Up'),
          :offText   => _('Down'),
        },
        {
          :component => 'switch',
          :id        => 'cloud_network_shared',
          :name      => 'shared',
          :label     => _('Shared'),
          :onText    => _('Yes'),
          :offText   => _('No'),
        },
      ]
    }
  end

  def params_for_update
    {
      :fields => [
        {
          :component => 'sub-form',
          :title     => _('Placement'),
          :id        => 'placement',
          :name      => 'placement',
          :fields    => [
            {
              :component       => 'select',
              :id              => 'cloud_tenant',
              :name            => 'cloud_tenant',
              :key             => "id-#{ems_id}",
              :label           => _('Cloud Tenant'),
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
          ]
        },
        {
          :component => 'sub-form',
          :title     => _('Network Provider Information'),
          :id        => 'provider-information',
          :name      => 'provider-information',
          :condition => {
            :when       => 'cloud_tenant',
            :isNotEmpty => true,
          },
          :fields    => [
            {
              :component   => 'select',
              :id          => 'provider_network_type',
              :name        => 'provider_network_type',
              :label       => _('Provider Network Type'),
              :placeholder => _('Nothing selected'),
              :options     => [
                {:label => _('None')},
                {:label => _('Local'),  :value => 'local'},
                {:label => _('Flat'),   :value => 'flat'},
                {:label => _('GRE'),    :value => 'gre'},
                {:label => _('GENEVE'), :value => 'geneve'},
                {:label => _('VLAN'),   :value => 'vlan'},
                {:label => _('VXLAN'),  :value => 'vxlan'}
              ],
              :isDisabled  => !!id,
            },
            {
              :component => 'sub-form',
              :id        => 'subform-1',
              :name      => 'subform-1',
              :condition => {
                :when => 'provider_network_type',
                :is   => 'flat',
              },
              :fields    => [
                {
                  :component       => 'text-field',
                  :label           => _('Physical Network'),
                  :maxLength       => 128,
                  :id              => 'provider_physical_network',
                  :name            => 'provider_physical_network',
                  :isDisabled      => !!id,
                  :validateOnMount => true,
                  :clearOnUnmount  => true,
                  :validate        => [{
                    :type    => 'required',
                    :message => _('Required'),
                  }],
                },
              ],
            },
            {
              :component => 'sub-form',
              :id        => 'subform-2',
              :name      => 'subform-2',
              :condition => {
                :when => 'provider_network_type',
                :is   => 'gre',
              },
              :fields    => [
                {
                  :component       => 'text-field',
                  :label           => _('Segmentation ID'),
                  :maxLength       => 128,
                  :id              => 'provider_segmentation_id',
                  :name            => 'provider_segmentation_id',
                  :isDisabled      => !!id,
                  :validateOnMount => true,
                  :clearOnUnmount  => true,
                  :validate        => [{
                    :type    => 'required',
                    :message => _('Required'),
                  }],
                }
              ]
            },
            {
              :component => 'sub-form',
              :id        => 'subform-3',
              :name      => 'subform-3',
              :condition => {
                :when => 'provider_network_type',
                :is   => 'vlan',
              },
              :fields    => [
                {
                  :component       => 'text-field',
                  :label           => _('Physical Network'),
                  :maxLength       => 128,
                  :id              => 'provider_physical_network',
                  :name            => 'provider_physical_network',
                  :isDisabled      => !!id,
                  :validateOnMount => true,
                  :clearOnUnmount  => true,
                  :validate        => [{
                    :type    => 'required',
                    :message => _('Required'),
                  }],
                },
                {
                  :component       => 'text-field',
                  :label           => _('Segmentation ID'),
                  :maxLength       => 128,
                  :id              => 'provider_segmentation_id',
                  :name            => 'provider_segmentation_id',
                  :isDisabled      => !!id,
                  :validateOnMount => true,
                  :clearOnUnmount  => true,
                  :validate        => [{
                    :type    => 'required',
                    :message => _('Required'),
                  }],
                }
              ]
            },
            {
              :component => 'sub-form',
              :id        => 'subform-4',
              :name      => 'subform-4',
              :condition => {
                :when => 'provider_network_type',
                :is   => 'vxlan',
              },
              :fields    => [
                {
                  :component      => 'text-field',
                  :label          => _('Segmentation ID'),
                  :maxLength      => 128,
                  :id             => 'provider_segmentation_id',
                  :name           => 'provider_segmentation_id',
                  :isDisabled     => !!id,
                  :clearOnUnmount => true,
                }
              ]
            }
          ],
        },
        {
          :component => 'sub-form',
          :title     => _('Network Information'),
          :id        => 'network-information',
          :name      => 'network-information',
          :fields    => [
            {
              :component       => 'text-field',
              :id              => 'name',
              :name            => 'name',
              :validateOnMount => true,
              :label           => _('Network Name'),
              :validate        => [
                {
                  :type    => 'required',
                  :message => _('Required'),
                }
              ]
            }
          ]
        },
        {
          :component => 'switch',
          :id        => 'cloud_network_external_facing',
          :name      => 'external_facing',
          :label     => _('External Router'),
          :onText    => _('Yes'),
          :offText   => _('No'),
        },
        {
          :component => 'switch',
          :id        => 'cloud_network_enabled',
          :name      => 'enabled',
          :label     => _('Adminstrative State'),
          :onText    => _('Up'),
          :offText   => _('Down'),
        },
        {
          :component => 'switch',
          :id        => 'cloud_network_shared',
          :name      => 'shared',
          :label     => _('Shared'),
          :onText    => _('Yes'),
          :offText   => _('No'),
        },
      ]
    }
  end

  def self.class_by_ems(ext_management_system, external = false)
    external ? super::Public : super::Private
  end

  def self.remapping(options)
    new_options = options.dup
    new_options[:router_external] = options[:external_facing] if options[:external_facing]
    new_options.delete(:external_facing)
    new_options
  end

  def self.raw_create_cloud_network(ext_management_system, options)
    cloud_tenant = options.delete(:cloud_tenant)
    network = nil
    raw_options = remapping(options)
    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      network = service.networks.new(raw_options)
      network.save
    end
    {:ems_ref => network.id, :name => options[:name]}
  rescue => e
    _log.error "network=[#{options[:name]}], error: #{e}"
    parsed_error = parse_error_message_from_neutron_response(e)
    raise MiqException::MiqNetworkCreateError, parsed_error, e.backtrace
  end

  def raw_delete_cloud_network(_options = {})
    with_notification(:cloud_network_delete,
                      :options => {
                        :subject => self,
                      }) do
      ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
        service.delete_network(ems_ref)
      end
    end
  rescue => e
    _log.error "network=[#{name}], error: #{e}"
    raise MiqException::MiqNetworkDeleteError, parse_error_message_from_neutron_response(e), e.backtrace
  end

  def raw_update_cloud_network(options)
    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      service.update_network(ems_ref, options)
    end
  rescue => e
    _log.error "network=[#{name}], error: #{e}"
    raise MiqException::MiqNetworkUpdateError, parse_error_message_from_neutron_response(e), e.backtrace
  end

  def self.connection_options(cloud_tenant = nil)
    connection_options = {:service => "Network"}
    connection_options[:tenant_name] = cloud_tenant.name if cloud_tenant
    connection_options
  end

  def ip_address_total_count
    # TODO(lsmola) Rather storing this in DB? It should be changing only in refresh
    @ip_address_total_count ||= cloud_subnets.all.sum do |subnet|
      # We substract 1 because the first address of the pool is always reserved. For private network it is for DHCP, for
      # public network it's a port for Router.
      subnet.allocation_pools.sum { |x| (IPAddr.new(x["start"])..IPAddr.new(x["end"])).map(&:to_s).count - 1 }
    end
  end

  def ip_address_left_count(reload = false)
    @ip_address_left_count = nil if reload
    @ip_address_left_count ||= ip_address_total_count - ip_address_used_count(reload)
  end

  def ip_address_left_count_live(reload = false)
    @ip_address_left_count_live = nil if reload
    # Live method is asking API drectly for current count of consumed addresses
    @ip_address_left_count_live ||= ip_address_total_count - ip_address_used_count_live(reload)
  end

  def ip_address_used_count(reload = false)
    @ip_address_used_count = nil if reload
    if @public
      # Number of all floating Ips, since we are doing association by creating FloatingIP, because
      # associate is not atomic.
      @ip_address_used_count ||= floating_ips.count
    else
      @ip_address_used_count ||= vms.count
    end
  end

  def ip_address_used_count_live(reload = false)
    @ip_address_used_count_live = nil if reload
    if @public
      # Number of ports with fixed IPs plugged into the network. Live means it talks directly to OpenStack API
      # TODO(lsmola) we probably need paginated API call, there should be no multitenancy needed, but the current
      # UI code allows to mix tenants, so it could be needed, athough netron doesn seem to have --all-tenants calls,
      # so when I use admin, I can see other tenant resources. Investigate, fix.
      @ip_address_used_count_live ||= ext_management_system.with_provider_connection(
        :service     => "Network",
        :tenant_name => cloud_tenant.name
      ) do |connection|
        connection.floating_ips.all(:floating_network_id => ems_ref).count
      end
    else
      @ip_address_used_count_live ||= ext_management_system.with_provider_connection(
        :service     => "Network",
        :tenant_name => cloud_tenant.name
      ) do |connection|
        connection.ports.all(:network_id => ems_ref, :device_owner => "compute:None").count
      end
    end
  end

  def ip_address_utilization(reload = false)
    @ip_address_utilization = nil if reload
    # If total count is 0, utilization should be 100
    @ip_address_utilization ||= begin
      ip_address_total_count > 0 ? (100.0 / ip_address_total_count) * ip_address_used_count(reload) : 100
    end
  end

  def ip_address_utilization_live(reload = false)
    @ip_address_utilization_live = nil if reload
    # Live method is asking API drectly for current count of consumed addresses
    # If total count is 0, utilization should be 100
    @ip_address_utilization_live ||= begin
      ip_address_total_count > 0 ? (100.0 / ip_address_total_count) * ip_address_used_count_live(reload) : 100
    end
  end

  def self.display_name(number = 1)
    n_('Cloud Network (OpenStack)', 'Cloud Networks (OpenStack)', number)
  end

  private

  def connection_options(cloud_tenant = nil)
    self.class.connection_options(cloud_tenant)
  end
end

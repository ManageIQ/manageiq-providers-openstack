class ManageIQ::Providers::Openstack::StorageManager::SwiftManager::CloudObjectStoreContainer < ::CloudObjectStoreContainer
  include ManageIQ::Providers::Openstack::HelperMethods
  include SupportsFeatureMixin

  supports :create
  supports :delete

  def self.params_for_create(ems)
    cloud_tenants = ems.parent_manager.cloud_tenants
    {
      :fields => [
        {
          :component  => 'text-field',
          :name       => 'name',
          :id         => 'name',
          :label      => _('Container Name'),
          :isRequired => true,
          :validate   => [{:type => 'required'}],
        },
        {
          :component    => 'select',
          :name         => 'cloud_tenant_id',
          :id           => 'cloud_tenant_id',
          :label        => _('Cloud Tenant'),
          :isRequired   => true,
          :includeEmpty => true,
          :validate     => [{:type => 'required'}],
          :options      => cloud_tenants.map do |ct|
            {:label => ct.name, :value => ct.id.to_s}
          end
        }
      ]
    }
  end

  def self.raw_cloud_object_store_container_create(ext_management_system, options)
    cloud_tenant_id = options.delete(:cloud_tenant_id)
    cloud_tenant = CloudTenant.find_by(:id => cloud_tenant_id) if cloud_tenant_id
    project_id = ''

    options[:key] = options[:name]
    with_notification(:cloud_container_create, :options => {:cloud_container_name => options[:name]}) do
      ext_management_system.with_provider_connection(swift_connection_options(cloud_tenant)) do |service|
        project_id = service.get_current_tenant.id
        directory = service.directories.new(options)
        directory.save
      end
    end

    {:ems_ref => "#{project_id}/#{options[:name]}", :key => options[:name], :object_count => 0, :bytes => 0,
     :ems_id => ext_management_system.id, :cloud_tenant_id => cloud_tenant_id}
  rescue => e
    _log.error("container=[#{options[:name]}], error: #{e}")
    parsed_error = parse_error_message_from_neutron_response(e)
    raise MiqException::Error, parsed_error, e.backtrace
  end

  def self.swift_connection_options(cloud_tenant = nil)
    connection_options = {:service => "Storage"}
    connection_options[:tenant_name] = cloud_tenant.name if cloud_tenant
    connection_options[:proxy] = openstack_proxy if openstack_proxy
    connection_options
  end

  def swift_connection_options
    self.class.swift_connection_options(cloud_tenant)
  end

  def self.validate_create_object_store_container(ext_management_system)
    validate_cloud_object_store_container(ext_management_system)
  end

  def raw_delete
    ext_management_system.with_provider_connection(swift_connection_options) do |service|
      service.delete_container(key)
    end
  rescue => e
    _log.error("container=[#{key}], error: #{e}")
    raise MiqException::MiqNetworkDeleteError, parse_error_message_from_neutron_response(e), e.backtrace
  end
end

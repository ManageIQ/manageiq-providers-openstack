class ManageIQ::Providers::Openstack::StorageManager::SwiftManager::CloudObjectStoreContainer < ::CloudObjectStoreContainer
  include ManageIQ::Providers::Openstack::HelperMethods

  def self.raw_cloud_object_store_container_create(ext_management_system, options)
    cloud_tenant = options.delete(:cloud_tenant)
    with_notification(:cloud_volume_create,
                      :options => {:volume_name => options[:name]}) do
      ext_management_system.with_provider_connection(swift_connection_options(cloud_tenant)) do |service|
        # create object_container
      end
    end
    # return hash for created container
  end

  def with_provider_connection
    super(swift_connection_options)
  end

  def self.swift_connection_options(cloud_tenant = nil)
    connection_options = {:service => "Storage"}
    connection_options[:tenant_name] = cloud_tenant.name if cloud_tenant
    connection_options[:provider_name] = "openstack Swift Manager"
    connection_options
  end

  def swift_connection_options
    self.class.swift_connection_options(cloud_tenant)
  end
end

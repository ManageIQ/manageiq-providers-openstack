class ManageIQ::Providers::Openstack::CloudManager::CloudVolumeBackup < ::CloudVolumeBackup
  include SupportsFeatureMixin

  supports :delete
  supports :backup_restore

  def raw_restore(volumeid)
    with_provider_object do |backup|
      backup.restore(volumeid)
    end
  rescue => e
    _log.error("backup=[#{name}], error: #{e}")
    raise MiqException::MiqOpenstackApiRequestError, e.to_s, e.backtrace
  end

  def raw_delete
    with_provider_object do |backup|
      backup.destroy if backup
    end
  rescue => e
    _log.error("volume backup=[#{name}], error: #{e}")
    raise MiqException::MiqOpenstackApiRequestError, e.to_s, e.backtrace
  end

  def with_provider_object
    super(connection_options)
  end

  def self.connection_options(cloud_tenant = nil)
    connection_options = { :service => 'Volume' }
    connection_options[:tenant_name] = cloud_tenant.name if cloud_tenant
    connection_options
  end

  def provider_object(connection)
    connection.backups.get(ems_ref)
  end

  def with_provider_connection
    super(connection_options)
  end

  private

  def connection_options
    self.class.connection_options(cloud_tenant)
  end
end

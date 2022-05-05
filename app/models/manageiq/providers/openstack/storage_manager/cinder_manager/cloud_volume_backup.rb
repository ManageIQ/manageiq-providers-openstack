class ManageIQ::Providers::Openstack::StorageManager::CinderManager::CloudVolumeBackup < ::CloudVolumeBackup
  include ManageIQ::Providers::Openstack::HelperMethods
  include SupportsFeatureMixin

  supports :delete
  supports :backup_restore

  def raw_restore(volumeid = nil, name = nil)
    with_notification(:cloud_volume_backup_restore,
                      :options => {
                        :subject     => self,
                        :volume_name => cloud_volume.name
                      }) do
      with_provider_object do |backup|
        backup.restore(volumeid, name)
      end
    end
  rescue => e
    parsed_error = parse_error_message_from_fog_response(e)

    _log.error("backup=[#{name}], error: #{parsed_error}")
    raise MiqException::MiqOpenstackApiRequestError, parsed_error, e.backtrace
  end

  def raw_delete
    with_notification(:cloud_volume_backup_delete,
                      :options => {
                        :subject     => self,
                        :volume_name => cloud_volume.name
                      }) do
      with_provider_object do |backup|
        backup&.destroy
      end
    end
  rescue => e
    parsed_error = parse_error_message_from_fog_response(e)

    _log.error("volume backup=[#{name}], error: #{parsed_error}")
    raise MiqException::MiqOpenstackApiRequestError, parsed_error, e.backtrace
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

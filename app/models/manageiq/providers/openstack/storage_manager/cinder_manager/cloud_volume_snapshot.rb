class ManageIQ::Providers::Openstack::StorageManager::CinderManager::CloudVolumeSnapshot < ::CloudVolumeSnapshot
  include ManageIQ::Providers::Openstack::HelperMethods
  include SupportsFeatureMixin

  supports :create
  supports :update
  supports :delete

  def provider_object(connection)
    connection.snapshots.get(ems_ref)
  end

  def with_provider_object
    super(connection_options)
  end

  def self.raw_create_snapshot(cloud_volume, options = {})
    raise ArgumentError, _("cloud_volume cannot be nil") if cloud_volume.nil?
    ext_management_system = cloud_volume.try(:ext_management_system)
    raise ArgumentError, _("ext_management_system cannot be nil") if ext_management_system.nil?

    cloud_tenant = cloud_volume.cloud_tenant
    snapshot = nil
    options[:volume_id] = cloud_volume.ems_ref
    with_notification(:cloud_volume_snapshot_create,
                      :options => {
                        :snapshot_name => options[:name],
                        :volume_name   => cloud_volume.name,
                      }) do
      ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
        snapshot = service.snapshots.create(options)
      end
    end

    create(
      :name                  => snapshot.name,
      :description           => snapshot.description,
      :ems_ref               => snapshot.id,
      :status                => snapshot.status,
      :cloud_volume          => cloud_volume,
      :cloud_tenant          => cloud_tenant,
      :ext_management_system => ext_management_system,
    )
  rescue => e
    parsed_error = parse_error_message_from_fog_response(e)

    _log.error("snapshot=[#{options[:name]}], error: #{parsed_error}")
    raise MiqException::MiqVolumeSnapshotCreateError, parsed_error, e.backtrace
  end

  def raw_update_snapshot(options = {})
    with_provider_object do |snapshot|
      if snapshot
        snapshot.update(options)
      else
        raise MiqException::MiqVolumeSnapshotUpdateError("snapshot does not exist")
      end
    end
  rescue => e
    parsed_error = parse_error_message_from_fog_response(e)

    _log.error("snapshot=[#{name}], error: #{parsed_error}")
    raise MiqException::MiqVolumeSnapshotUpdateError, parsed_error, e.backtrace
  end

  def raw_delete_snapshot(_options = {})
    with_notification(:cloud_volume_snapshot_delete,
                      :options => {
                        :subject       => self,
                        :volume_name   => cloud_volume.name,
                      }) do
      with_provider_object do |snapshot|
        if snapshot
          snapshot.destroy
        else
          _log.warn("snapshot=[#{name}] already deleted")
        end
      end
    end
  rescue => e
    parsed_error = parse_error_message_from_fog_response(e)

    _log.error("snapshot=[#{name}], error: #{parsed_error}")
    raise MiqException::MiqVolumeSnapshotDeleteError, parsed_error, e.backtrace
  end

  def self.connection_options(cloud_tenant = nil)
    connection_options = { :service => 'Volume' }
    connection_options[:tenant_name] = cloud_tenant.name if cloud_tenant
    connection_options
  end

  private

  def connection_options
    self.class.connection_options(cloud_tenant)
  end
end

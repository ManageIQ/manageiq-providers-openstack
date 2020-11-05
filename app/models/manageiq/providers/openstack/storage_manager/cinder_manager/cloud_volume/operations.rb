module ManageIQ::Providers::Openstack::StorageManager::CinderManager::CloudVolume::Operations
  def validate_attach_volume
    validate_volume_available
  end

  def validate_detach_volume
    validate_volume_in_use
  end

  def raw_attach_volume(server_ems_ref, device = nil)
    device = nil if device.try(:empty?)
    with_notification(:cloud_volume_attach,
                      :options => {
                        :subject =>       self,
                        :instance_name => server_ems_ref,
                      }) do
      ext_management_system.with_provider_connection(connection_options) do |service|
        service.servers.get(server_ems_ref).attach_volume(ems_ref, device)
      end
    end
  rescue => e
    volume_name = name.presence || ems_ref
    _log.error("volume=[#{volume_name}], error: #{e}")
    raise MiqException::MiqVolumeAttachError, parse_error_message_from_fog_response(e), e.backtrace
  end

  def raw_detach_volume(server_ems_ref)
    with_notification(:cloud_volume_detach,
                      :options => {
                        :subject =>       self,
                        :instance_name => server_ems_ref,
                      }) do
      ext_management_system.with_provider_connection(connection_options) do |service|
        service.servers.get(server_ems_ref).detach_volume(ems_ref)
      end
    end
  rescue => e
    volume_name = name.presence || ems_ref
    _log.error("volume=[#{volume_name}], error: #{e}")
    raise MiqException::MiqVolumeDetachError, parse_error_message_from_fog_response(e), e.backtrace
  end
end

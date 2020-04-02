module ManageIQ::Providers::Openstack::CloudManager::Provision::VolumeAttachment
  def create_requested_volumes(requested_volumes)
    volumes_attrs_list = [default_volume_attributes]

    connection_options = {:service => "volume", :tenant_name => cloud_tenant.try(:name)}
    source.ext_management_system.with_provider_connection(connection_options) do |service|
      requested_volumes.each do |volume_attrs|
        new_volume_id = service.volumes.create(volume_attrs).id
        new_volume_attrs = volume_attrs.clone
        new_volume_attrs[:uuid]             = new_volume_id
        new_volume_attrs[:source_type]      = 'volume'
        new_volume_attrs[:destination_type] = 'volume'
        volumes_attrs_list << new_volume_attrs
      end
    end if requested_volumes.any?
    volumes_attrs_list
  end

  def configure_volumes
    phase_context[:requested_volumes]
  end

  def do_volume_creation_check(volumes_refs)
    connection_options = {:service => "volume", :tenant_name => cloud_tenant.try(:name)}
    source.ext_management_system.with_provider_connection(connection_options) do |service|
      volumes_refs.each do |volume_attrs|
        next unless volume_attrs[:source_type] == "volume"
        volume = service.volumes.get(volume_attrs[:uuid])
        status = volume.try(:status)
        if status == "error"
          raise MiqException::MiqProvisionError, "An error occurred while creating Volume #{volume.name}"
        end
        return false, status unless status == "available"
      end
    end
    true
  end

  def default_volume_attributes
    {
      :name                  => "root",
      :size                  => instance_type.root_disk_size / 1.gigabyte,
      :source_type           => "image",
      :destination_type      => "local",
      :boot_index            => 0,
      :delete_on_termination => true,
      :uuid                  => source.ems_ref
    }
  end
end

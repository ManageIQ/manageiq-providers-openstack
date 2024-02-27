class ManageIQ::Providers::Openstack::StorageManager::CinderManager::CloudVolume < ::CloudVolume
  include ManageIQ::Providers::Openstack::HelperMethods
  include Operations

  supports :backup_create
  supports :backup_restore
  supports :create
  supports :delete do
    if !ext_management_system
      _("the volume is not connected to an active Provider")
    elsif status == "in-use"
      _("cannot delete volume that is in use.")
    end
  end
  supports :snapshot_create
  supports :update do
    _("The Volume is not connected to an active Provider") unless ext_management_system
  end

  def self.params_for_create(ems)
    {
      :fields => [
        {
          :component  => 'text-field',
          :name       => 'size',
          :id         => 'size',
          :label      => _('Size (in bytes)'),
          :type       => 'number',
          :step       => 1.gigabytes,
          :isRequired => true,
          :validate   => [{:type => 'required'}, {:type => 'min-number-value', :value => 1, :message => _('Size must be greater than or equal to 1')}],
        },
        {
          :component    => 'select',
          :name         => 'cloud_tenant_id',
          :id           => 'cloud_tenant_id',
          :label        => _('Cloud Tenant'),
          :isRequired   => true,
          :includeEmpty => true,
          :validate     => [{:type => 'required'}],
          :options      => ems.cloud_tenants.map do |ct|
            {
              :label => ct.name,
              :value => ct.id.to_s,
            }
          end,
        },
        {
          :component    => 'select',
          :name         => 'availability_zone_id',
          :id           => 'availability_zone_id',
          :label        => _('Availability Zone'),
          :includeEmpty => true,
          :options      => ems.volume_availability_zones.map do |az|
            {
              :label => az.name,
              :value => az.id,
            }
          end,
        },
        {
          :component    => 'select',
          :name         => 'volume_type',
          :id           => 'volume_type',
          :label        => _('Cloud Volume Type'),
          :includeEmpty => true,
          :options      => ems.cloud_volume_types.map do |cvt|
            {
              :label => cvt.name,
              :value => cvt.name,
            }
          end,
        },
      ]
    }
  end

  def params_for_update
    {
      :fields => [
        {
          :component  => 'text-field',
          :name       => 'size',
          :id         => 'size',
          :label      => _('Size (in bytes)'),
          :type       => 'number',
          :step       => 1.gigabytes,
          :isRequired => true,
          :validate   => [{:type => 'required'}, {:type => 'min-number-value', :value => 1, :message => _('Size must be greater than or equal to 1')}],
        },
        {
          :component  => 'select',
          :name       => 'cloud_tenant_id',
          :id         => 'cloud_tenant_id',
          :label      => _('Cloud Tenant'),
          :isRequired => true,
          :validate   => [{:type => 'required'}],
          :isDisabled => !!id,
          :options    => ext_management_system.cloud_tenants.map do |ct|
            {
              :label => ct.name,
              :value => ct.id.to_s,
            }
          end,
        },
        {
          :component    => 'select',
          :name         => 'availability_zone_id',
          :id           => 'availability_zone_id',
          :label        => _('Availability Zone'),
          :includeEmpty => true,
          :isDisabled   => !!id,
          :options      => ext_management_system.volume_availability_zones.map do |az|
            {
              :label => az.name,
              :value => az.id,
            }
          end,
        },
        {
          :component    => 'select',
          :name         => 'volume_type',
          :id           => 'volume_type',
          :label        => _('Cloud Volume Type'),
          :includeEmpty => true,
          :isDisabled   => !!id,
          :options      => ext_management_system.cloud_volume_types.map do |cvt|
            {
              :label => cvt.name,
              :value => cvt.name,
            }
          end,
        },
      ]
    }
  end

  def params_for_attach
    {
      :fields => [
        {
          :component => 'text-field',
          :name      => 'device_mountpoint',
          :id        => 'device_mountpoint',
          :label     => _('Device Mountpoint')
        }
      ]
    }
  end

  def self.raw_create_volume(ext_management_system, options)
    options = options.symbolize_keys

    cloud_tenant_id = options.delete(:cloud_tenant_id)
    cloud_tenant    = CloudTenant.find_by(:id => cloud_tenant_id) if cloud_tenant_id
    volume = nil

    # provide display_name for Cinder V1
    options[:display_name] |= options[:name]
    with_notification(:cloud_volume_create, :options => {:volume_name => options[:name]}) do
      ext_management_system.with_provider_connection(cinder_connection_options(cloud_tenant)) do |service|
        volume = service.volumes.new(options)
        volume.save
      end
    end
    {:ems_ref => volume.id, :status => volume.status, :name => options[:name]}
  rescue => e
    parsed_error = parse_error_message_from_fog_response(e)

    _log.error("volume=[#{options[:name]}], error: #{parsed_error}")
    raise MiqException::MiqVolumeCreateError, parsed_error, e.backtrace
  end

  def raw_update_volume(options)
    options = options.symbolize_keys

    with_notification(:cloud_volume_update, :options => {:subject => self}) do
      with_provider_object do |volume|
        size = options.delete(:size)
        volume.attributes.merge!(options)
        volume.save
        volume.extend(size) if size.to_i != volume.size.to_i
      end
    end
  rescue => e
    parsed_error = parse_error_message_from_fog_response(e)

    _log.error("volume=[#{name}], error: #{parsed_error}")
    raise MiqException::MiqVolumeUpdateError, parsed_error, e.backtrace
  end

  def raw_delete_volume
    with_notification(:cloud_volume_delete,
                      :options => {
                        :subject => self,
                      }) do
      with_provider_object { |volume| volume.try(:destroy) }
    end
  rescue => e
    _log.error "volume=[#{name}], error: #{e}"
    raise MiqException::MiqVolumeDeleteError, parse_error_message_from_fog_response(e), e.backtrace
  end

  def backup_create(options)
    options[:volume_id] = ems_ref
    with_notification(:cloud_volume_backup_create,
                      :options => {
                        :subject     => self,
                        :backup_name => options[:name]
                      }) do
      with_provider_connection do |service|
        backup = service.backups.new(options)
        backup.save
      end
    end
  rescue => e
    parsed_error = parse_error_message_from_fog_response(e)

    _log.error("backup=[#{name}], error: #{parsed_error}")
    raise MiqException::MiqVolumeBackupCreateError, parsed_error, e.backtrace
  end

  def backup_create_queue(userid, options = {})
    task_opts = {
      :action => "creating Cloud Volume Backup for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'backup_create',
      :instance_id => id,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def backup_restore(backup_id)
    with_provider_connection do |service|
      backup = service.backups.get(backup_id)
      backup.restore(ems_ref)
    end
  rescue => e
    parsed_error = parse_error_message_from_fog_response(e)

    _log.error("volume=[#{name}], error: #{parsed_error}")
    raise MiqException::MiqVolumeBackupRestoreError, parsed_error, e.backtrace
  end

  def backup_restore_queue(userid, backup_id)
    task_opts = {
      :action => "restoring Cloud Volume from Backup for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'backup_restore',
      :instance_id => id,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [backup_id]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def available_vms
    cloud_tenant.vms.where.not(:id => vms.select(&:id))
  end

  def provider_object(connection)
    connection.volumes.get(ems_ref)
  end

  def with_provider_object
    super(cinder_connection_options)
  end

  def with_provider_connection
    super(cinder_connection_options)
  end

  def self.cinder_connection_options(cloud_tenant = nil)
    connection_options = {:service => "Volume"}
    connection_options[:tenant_name] = cloud_tenant.name if cloud_tenant
    connection_options[:proxy] = openstack_proxy if openstack_proxy
    connection_options
  end

  private_class_method :cinder_connection_options

  private

  def connection_options
    # TODO(lsmola) expand with cinder connection when we have Cinder v2, based on respond to on service.volumes method,
    #  but best if we can fetch endpoint list and do discovery of available versions
    nova_connection_options
  end

  def nova_connection_options
    connection_options = {:service => "Compute"}
    connection_options[:tenant_name] = cloud_tenant.name if cloud_tenant
    connection_options[:proxy] = openstack_proxy if openstack_proxy
    connection_options
  end

  def cinder_connection_options
    self.class.send(:cinder_connection_options, cloud_tenant)
  end
end

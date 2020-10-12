class ManageIQ::Providers::Openstack::StorageManager::CinderManager::CloudVolume < ::CloudVolume
  include ManageIQ::Providers::Openstack::HelperMethods
  include_concern 'Operations'

  include SupportsFeatureMixin

  supports :create
  supports :backup_create
  supports :backup_restore
  supports :snapshot_create

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
          :validate   => [{:type => 'required'}],
        },
        {
          :component  => 'select',
          :name       => 'cloud_tenant_id',
          :id         => 'cloud_tenant_id',
          :label      => _('Cloud Tenant'),
          :isRequired => true,
          :validate   => [{:type => 'required'}],
          :condition  => {
            :when => 'edit',
            :is   => false,
          },
          :options    => ems.cloud_tenants.map do |ct|
            {
              :label => ct.name,
              :value => ct.id,
            }
          end,
        },
        {
          :component => 'select',
          :name      => 'availability_zone_id',
          :id        => 'availability_zone_id',
          :label     => _('Availability Zone'),
          :condition => {
            :when => 'edit',
            :is   => false,
          },
          :options   => ems.availability_zones.map do |az|
            {
              :label => az.name,
              :value => az.id,
            }
          end,
        },
        {
          :component => 'select',
          :name      => 'volume_type',
          :id        => 'volume_type',
          :label     => _('Cloud Volume Type'),
          :condition => {
            :when => 'edit',
            :is   => false,
          },
          :options   => ems.cloud_volume_types.map do |cvt|
            {
              :label => cvt.name,
              :value => cvt.type,
            }
          end,
        },
      ]
    }
  end

  def self.validate_create_volume(ext_management_system)
    validate_volume(ext_management_system)
  end

  def self.raw_create_volume(ext_management_system, options)
    cloud_tenant = options.delete(:cloud_tenant)
    volume = nil

    # provide display_name for Cinder V1
    options[:display_name] |= options[:name]
    with_notification(:cloud_volume_create,
                      :options => {
                        :volume_name => options[:name],
                      }) do
      ext_management_system.with_provider_connection(cinder_connection_options(cloud_tenant)) do |service|
        volume = service.volumes.new(options)
        volume.save
      end
    end
    {:ems_ref => volume.id, :status => volume.status, :name => options[:name]}
  rescue => e
    _log.error "volume=[#{options[:name]}], error: #{e}"
    raise MiqException::MiqVolumeCreateError, parse_error_message_from_fog_response(e), e.backtrace
  end

  def validate_update_volume
    validate_volume
  end

  def raw_update_volume(options)
    with_notification(:cloud_volume_update,
                      :options => {
                        :subject => self,
                      }) do
      with_provider_object do |volume|
        size = options.delete(:size)
        volume.attributes.merge!(options)
        volume.save
        volume.extend(size) if size.to_i != volume.size.to_i
      end
    end
  rescue => e
    _log.error "volume=[#{name}], error: #{e}"
    raise MiqException::MiqVolumeUpdateError, parse_error_message_from_fog_response(e), e.backtrace
  end

  def validate_delete_volume
    msg = validate_volume
    return {:available => msg[:available], :message => msg[:message]} unless msg[:available]
    if status == "in-use"
      return validation_failed("Delete Volume", "Can't delete volume that is in use.")
    end
    {:available => true, :message => nil}
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
    _log.error "backup=[#{name}], error: #{e}"
    raise MiqException::MiqVolumeBackupCreateError, parse_error_message_from_fog_response(e), e.backtrace
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
    _log.error "volume=[#{name}], error: #{e}"
    raise MiqException::MiqVolumeBackupRestoreError, parse_error_message_from_fog_response(e), e.backtrace
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

  def create_volume_snapshot(options)
    ManageIQ::Providers::Openstack::StorageManager::CinderManager::CloudVolumeSnapshot.create_snapshot(self, options)
  end

  def create_volume_snapshot_queue(userid, options)
    ManageIQ::Providers::Openstack::StorageManager::CinderManager::CloudVolumeSnapshot
      .create_snapshot_queue(userid, self, options)
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

  def self.cinder_connection_options(cloud_tenant = nil)
    connection_options = {:service => "Volume"}
    connection_options[:tenant_name] = cloud_tenant.name if cloud_tenant
    connection_options[:proxy] = openstack_proxy if openstack_proxy
    connection_options
  end

  def cinder_connection_options
    self.class.cinder_connection_options(cloud_tenant)
  end
end

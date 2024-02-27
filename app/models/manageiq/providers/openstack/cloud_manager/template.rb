class ManageIQ::Providers::Openstack::CloudManager::Template < ManageIQ::Providers::Openstack::CloudManager::BaseTemplate
  include ManageIQ::Providers::Openstack::HelperMethods
  belongs_to :cloud_tenant

  include ManageIQ::Providers::Openstack::CloudManager::VmOrTemplateShared

  has_and_belongs_to_many :cloud_tenants,
                          :foreign_key             => "vm_id",
                          :join_table              => "cloud_tenants_vms",
                          :association_foreign_key => "cloud_tenant_id",
                          :class_name              => "ManageIQ::Providers::Openstack::CloudManager::CloudTenant"

  supports :create_image do
    if ext_management_system.nil?
      _("The Image is not connected to an active %{table}") % {:table => ui_lookup(:table => "ext_management_system")}
    end
  end

  supports :delete_image

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.images.get(ems_ref)
  end

  def perform_metadata_scan(ost)
    require 'OpenStackExtract/MiqOpenStackVm/MiqOpenStackImage'

    image_id = ems_ref
    _log.debug "image_id = #{image_id}"
    ost.scanTime = Time.now.utc unless ost.scanTime

    ems = ext_management_system
    os_handle = ems.openstack_handle

    begin
      miqVm = MiqOpenStackImage.new(image_id, :os_handle => os_handle)
      scan_via_miq_vm(miqVm, ost)
    ensure
      miqVm.unmount if miqVm
    end
  end

  def perform_metadata_sync(ost)
    sync_stashed_metadata(ost)
  end

  # TODO: Does this code need to be reimplemented?
  def proxies4job(_job = nil)
    {
      :proxies => [MiqServer.my_server],
      :message => 'Perform SmartState Analysis on this Image'
    }
  end

  def allocated_disk_storage
    hardware.try(:size_on_disk)
  end

  def has_active_proxy?
    true
  end

  def has_proxy?
    true
  end

  def requires_storage_for_scan?
    false
  end

  def self.raw_create_image(ext_management_system, create_options)
    ext_management_system.with_provider_connection(:service => 'Image') do |service|
      service.create_image(create_options)
    end
  rescue => err
    _log.error("image=[#{name}], error=[#{err}]")
    raise MiqException::MiqOpenstackApiRequestError, parse_error_message_from_fog_response(err), err.backtrace
  end

  def self.create_image(ext_management_system, create_options)
    raw_create_image(ext_management_system, create_options)
  end

  def raw_update_image(options)
    ext_management_system.with_provider_connection(:service => 'Image') do |service|
      image_attrs = service.images.find_by_id(ems_ref).attributes.stringify_keys
      options = options.select { |k| image_attrs.key?(k) }
      service.images.find_by_id(ems_ref).update(options)
    end
  rescue => err
    _log.error("image=[#{name}], error: #{err}")
    raise MiqException::MiqOpenstackApiRequestError, parse_error_message_from_fog_response(err), err.backtrace
  end

  def update_image(options)
    raw_update_image(options)
  end

  def raw_delete_image
    ext_management_system.with_provider_connection(:service => 'Image') do |service|
      service.delete_image(ems_ref)
    end
  rescue => err
    _log.error("image=[#{name}], error: #{err}")
    raise MiqException::MiqOpenstackApiRequestError, parse_error_message_from_fog_response(err), err.backtrace
  end

  def delete_image
    raw_delete_image
  end

  def self.display_name(number = 1)
    n_('Image (OpenStack)', 'Images (OpenStack)', number)
  end
end

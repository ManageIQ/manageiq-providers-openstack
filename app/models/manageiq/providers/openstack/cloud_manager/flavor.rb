class ManageIQ::Providers::Openstack::CloudManager::Flavor < ::Flavor
  include ManageIQ::Providers::Openstack::HelperMethods

  supports :create
  supports :delete

  def self.raw_create_flavor(ext_management_system, create_options)
    ext_management_system.with_provider_connection({:service => 'Compute'}) do |service|
      cloud_tenant_refs = create_options.delete("cloud_tenant_refs")
      flavor = service.flavors.create(create_options)
      unless flavor.is_public
        cloud_tenant_refs.each do |cloud_tenant_ref|
          service.add_flavor_access(flavor.id, cloud_tenant_ref)
        end
      end
    end
  rescue => err
    _log.error "flavor=[#{name}], error=[#{err}]"
    raise MiqException::MiqOpenstackApiRequestError, parse_error_message_from_fog_response(err), err.backtrace
  end

  def raw_delete_flavor
    ext_management_system.with_provider_connection({:service => 'Compute'}) do |service|
      service.delete_flavor(ems_ref)
    end
  rescue => err
    _log.error "flavor=[#{name}], error: #{err}"
    raise MiqException::MiqOpenstackApiRequestError, parse_error_message_from_fog_response(err), err.backtrace
  end

  def description
    ram = ActionController::Base.helpers.number_to_human_size(memory)
    disk_size = ActionController::Base.helpers.number_to_human_size(root_disk_size)
    _("%{cpus} CPUs, %{ram} RAM, %{disk_size} Root Disk") % {:cpus => cpus, :ram => ram, :disk_size => disk_size}
  end

  def self.display_name(number = 1)
    n_('Flavor (OpenStack)', 'Flavors (OpenStack)', number)
  end
end

class ManageIQ::Providers::Openstack::CloudManager::Flavor < ::Flavor
  def self.raw_create_flavor(ext_management_system, create_options)
    ext_management_system.with_provider_connection({:service => 'Compute'}) do |service|
      service.flavors.create(create_options)
    end
  rescue => err
    _log.error "flavor=[#{name}], error=[#{err}]"
    raise MiqException::MiqOpenstackApiRequestError, err.to_s, err.backtrace
  end

  def self.validate_create_flavor(ext_management_system, _options = {})
    if ext_management_system
      {:available => true, :message => nil}
    else
      {:available => false,
       :message   => _("The Flavor is not connected to an active %{table}") %
         {:table => ui_lookup(:table => "ext_management_system")}}
    end
  end

  def raw_delete_flavor
    ext_management_system.with_provider_connection({:service => 'Compute'}) do |service|
      service.delete_flavor(ems_ref)
    end
  rescue => err
    _log.error "flavor=[#{name}], error: #{err}"
    raise MiqException::MiqOpenstackApiRequestError, err.to_s, err.backtrace
  end

  def validate_delete_flavor
    {:available => true, :message => nil}
  end
end

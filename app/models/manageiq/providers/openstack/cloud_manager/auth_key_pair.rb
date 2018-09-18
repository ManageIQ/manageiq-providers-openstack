class ManageIQ::Providers::Openstack::CloudManager::AuthKeyPair < ManageIQ::Providers::CloudManager::AuthKeyPair
  include ManageIQ::Providers::Openstack::HelperMethods

  def self.raw_create_key_pair(ext_management_system, create_options)
    connection_options = {:service => 'Compute'}
    ext_management_system.with_provider_connection(connection_options) do |service|
      service.key_pairs.create(create_options)
    end
  rescue => err
    _log.error "keypair=[#{name}], error: #{err}"
    raise MiqException::MiqOpenstackApiRequestError, parse_error_message_from_fog_response(err), err.backtrace
  end

  def self.validate_create_key_pair(ext_management_system, _options = {})
    if ext_management_system
      {:available => true, :message => nil}
    else
      {:available => false,
       :message   => _("The Keypair is not connected to an active %{table}") %
         {:table => ui_lookup(:table => "ext_management_system")}}
    end
  end

  def raw_delete_key_pair
    connection_options = {:service => 'Compute'}
    resource.with_provider_connection(connection_options) do |service|
      service.delete_key_pair(name)
    end
  rescue => err
    _log.error "keypair=[#{name}], error: #{err}"
    raise MiqException::MiqOpenstackApiRequestError, parse_error_message_from_fog_response(err), err.backtrace
  end

  def validate_delete_key_pair
    {:available => allow_delete?, :message => nil}
  end

  private

  # Returns false if an auth_key is available true if not.
  # Meaning we can delete if there is no auth_key.
  def allow_delete?
    !self.auth_key.present?
  end
end

class ManageIQ::Providers::Openstack::CloudManager::AuthKeyPair < ManageIQ::Providers::CloudManager::AuthKeyPair
  include ManageIQ::Providers::Openstack::HelperMethods

  supports :create
  supports :delete

  def self.raw_create_key_pair(ext_management_system, create_options)
    connection_options = {:service => 'Compute'}
    ext_management_system.with_provider_connection(connection_options) do |service|
      kp = service.key_pairs.create(create_options)

      {:name => kp.name, :fingerprint => kp.fingerprint, :auth_key => kp.private_key}
    end
  rescue => err
    _log.error "keypair=[#{name}], error: #{err}"
    raise MiqException::MiqOpenstackApiRequestError, parse_error_message_from_fog_response(err), err.backtrace
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
end

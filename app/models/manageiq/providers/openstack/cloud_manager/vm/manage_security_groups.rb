module ManageIQ::Providers::Openstack::CloudManager::Vm::ManageSecurityGroups
  extend ActiveSupport::Concern

  included do
    supports :add_security_group do
      if cloud_tenant.nil? || cloud_tenant.security_groups.empty?
        _("There are no %{security_groups} available to this %{instance}.") % {
          :security_groups => ui_lookup(:tables => "security_group"),
          :instance        => ui_lookup(:table => "vm_cloud")
        }
      end
    end
    supports :remove_security_group do
      if security_groups.empty?
        _("This %{instance} does not have any associated %{security_groups}") % {
          :instance        => ui_lookup(:table => 'vm_cloud'),
          :security_groups => ui_lookup(:tables => 'security_group')
        }
      end
    end
  end

  def raw_add_security_group(security_group)
    ext_management_system.with_provider_connection(compute_connection_options) do |connection|
      connection.add_security_group(ems_ref, security_group)
    end
  rescue => err
    _log.error "vm=[#{name}], security_group=[#{security_group}], error: #{err}"
    raise MiqException::MiqOpenstackApiRequestError, parse_error_message_from_fog_response(err), err.backtrace
  end

  def raw_remove_security_group(security_group)
    ext_management_system.with_provider_connection(compute_connection_options) do |connection|
      connection.remove_security_group(ems_ref, security_group)
    end
  rescue => err
    _log.error "vm=[#{name}], security_group=[#{security_group}], error: #{err}"
    raise MiqException::MiqOpenstackApiRequestError, parse_error_message_from_fog_response(err), err.backtrace
  end

  def compute_connection_options
    {:service => 'Compute', :tenant_name => cloud_tenant.name}
  end
end

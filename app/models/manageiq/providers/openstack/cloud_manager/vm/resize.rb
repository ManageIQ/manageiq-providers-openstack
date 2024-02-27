module ManageIQ::Providers::Openstack::CloudManager::Vm::Resize
  extend ActiveSupport::Concern

  included do
    supports :resize do
      if !ext_management_system
        _('The VM is not connected to a provider')
      elsif %w[ACTIVE SHUTOFF].exclude?(raw_power_state)
        _("The Instance cannot be resized, current state has to be active or shutoff.")
      else
        unsupported_reason(:control)
      end
    end
  end

  def raw_resize(options)
    ext_management_system.with_provider_connection(compute_connection_options) do |service|
      service.resize_server(ems_ref, options["flavor"])
    end
    MiqQueue.put(:class_name  => self.class.name,
                 :expires_on  => Time.now.utc + 2.hours,
                 :instance_id => id,
                 :method_name => "raw_resize_finish")
  rescue => err
    _log.error("vm=[#{name}], flavor=[#{options["flavor"]}], error: #{err}")
    raise MiqException::MiqOpenstackApiRequestError, parse_error_message_from_fog_response(err), err.backtrace
  end

  def params_for_resize
    {
      :fields => [
        {
          :component  => 'text-field',
          :name       => 'current_flavor',
          :id         => 'current_flavor',
          :label      => _('Current Flavor'),
          :isDisabled => true,
          :value      => flavor.name_with_details
        },
        {
          :component    => 'select',
          :name         => 'flavor',
          :id           => 'flavor',
          :label        => _('Choose Flavor'),
          :isRequired   => true,
          :includeEmpty => true,
          :options      => resize_form_options
        },
      ],
    }
  end

  def resize_form_options
    ext_management_system.flavors.map do |ems_flavor|
      # include only flavors with root disks at least as big as the instance's current root disk.
      next if flavor && (ems_flavor == flavor || ems_flavor.root_disk_size < flavor.root_disk_size)

      {:label => ems_flavor.name_with_details, :value => ems_flavor.ems_ref}
    end.compact
  end

  def validate_resize_confirm
    raw_power_state == 'VERIFY_RESIZE'
  end

  def raw_resize_confirm
    ext_management_system.with_provider_connection(compute_connection_options) do |service|
      service.confirm_resize_server(ems_ref)
    end
  rescue => err
    _log.error "vm=[#{name}], error: #{err}"
    raise MiqException::MiqOpenstackApiRequestError, parse_error_message_from_fog_response(err), err.backtrace
  end

  def raw_resize_finish
    refresh_ems
    raise MiqException::MiqQueueRetryLater.new(:deliver_on => Time.now.utc + 1.minute) unless validate_resize_confirm
    raw_resize_confirm
  end

  def validate_resize_revert
    raw_power_state == 'VERIFY_RESIZE'
  end

  def raw_resize_revert
    ext_management_system.with_provider_connection(compute_connection_options) do |service|
      service.revert_resize_server(ems_ref)
    end
  rescue => err
    _log.error "vm=[#{name}], error: #{err}"
    raise MiqException::MiqOpenstackApiRequestError, parse_error_message_from_fog_response(err), err.backtrace
  end

  def compute_connection_options
    {:service => 'Compute', :tenant_name => cloud_tenant.name}
  end
end

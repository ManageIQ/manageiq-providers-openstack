class ManageIQ::Providers::Openstack::CloudManager::OrchestrationStack < ManageIQ::Providers::CloudManager::OrchestrationStack
  include ManageIQ::Providers::Openstack::HelperMethods

  def self.raw_create_stack(orchestration_manager, stack_name, template, options = {})
    create_options = {:stack_name => stack_name, :template => template.content}.merge(options).except(:tenant_name)
    transform_parameters(template, create_options[:parameters]) if create_options[:parameters]
    connection_options = {:service => "Orchestration"}.merge(options.slice(:tenant_name))
    orchestration_manager.with_provider_connection(connection_options) do |service|
      service.stacks.new.save(create_options)["id"]
    end
  rescue => err
    _log.error "stack=[#{stack_name}], error: #{err}"
    raise MiqException::MiqOrchestrationProvisionError, parse_error_message_from_fog_response(err), err.backtrace
  end

  def raw_update_stack(template, options)
    update_options = {:template => template.content}.merge(options.except(:disable_rollback, :timeout_mins))
    self.class.transform_parameters(template, update_options[:parameters]) if update_options[:parameters]
    connection_options = {:service => "Orchestration"}
    connection_options[:tenant_name] = cloud_tenant.name if cloud_tenant
    ext_management_system.with_provider_connection(connection_options) do |service|
      service.stacks.get(name, ems_ref).save(update_options)
    end
  rescue => err
    _log.error "stack=[#{name}], error: #{err}"
    raise MiqException::MiqOrchestrationUpdateError, parse_error_message_from_fog_response(err), err.backtrace
  end

  def raw_delete_stack
    options = {:service => "Orchestration"}
    options[:tenant_name] = cloud_tenant.name if cloud_tenant
    ext_management_system.with_provider_connection(options) do |service|
      service.stacks.get(name, ems_ref).try(:delete)
    end
  rescue => err
    _log.error "stack=[#{name}], error: #{err}"
    raise MiqException::MiqOrchestrationDeleteError, parse_error_message_from_fog_response(err), err.backtrace
  end

  def raw_status
    ems = ext_management_system
    options = {:service => "Orchestration"}
    options[:tenant_name] = cloud_tenant.name if cloud_tenant
    ems.with_provider_connection(options) do |service|
      raw_stack = service.stacks.get(name, ems_ref)
      raise MiqException::MiqOrchestrationStackNotExistError, "#{name} does not exist on #{ems.name}" unless raw_stack

      Status.new(raw_stack.stack_status, raw_stack.stack_status_reason)
    end
  rescue MiqException::MiqOrchestrationStackNotExistError
    raise
  rescue => err
    _log.error "stack=[#{name}], error: #{err}"
    raise MiqException::MiqOrchestrationStatusError, parse_error_message_from_fog_response(err), err.backtrace
  end

  def self.transform_parameters(template, deploy_parameters)
    list_re = /^(comma_delimited_list)|(CommaDelimitedList)|(List<.+>)$/
    # convert multiline text to comma delimited string
    template.parameter_groups.each do |group|
      group.parameters.each do |para_def|
        next unless para_def.data_type =~ list_re
        parameter = deploy_parameters[para_def.name]
        next if parameter.nil? || !parameter.kind_of?(String)
        parameter.chomp!('')
        parameter.tr!("\n", ",")
      end
    end
  end

  def self.display_name(number = 1)
    n_('Orchestration Stack (OpenStack)', 'Orchestration Stacks (OpenStack)', number)
  end
end

class ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack < ::OrchestrationStack
  include ManageIQ::Providers::Openstack::HelperMethods

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::InfraManager"
  belongs_to :orchestration_template
  belongs_to :cloud_tenant

  def self.create_stack(orchestration_manager, stack_name, template, options = {})
    klass = orchestration_manager.class::OrchestrationStack
    ems_ref = klass.raw_create_stack(orchestration_manager, stack_name, template, options)

    klass.create(:name                   => stack_name,
                 :ems_ref                => ems_ref,
                 :status                 => 'CREATE_IN_PROGRESS',
                 :resource_group         => options[:resource_group],
                 :ext_management_system  => orchestration_manager,
                 :cloud_tenant           => tenant,
                 :orchestration_template => template)
  end

  def raw_update_stack(template, parameters)
    ext_management_system.with_provider_connection(:service => "Orchestration") do |connection|
      stack    = connection.stacks.get(name, ems_ref)
      template ||= connection.get_stack_template(stack).body

      connection.patch_stack(stack, 'template' => template, 'parameters' => parameters)
    end
  rescue => err
    _log.error "stack=[#{name}], error: #{err}"
    raise MiqException::MiqOrchestrationUpdateError, parse_error_message_from_fog_response(err), err.backtrace
  end

  def update_ready?
    # Update is possible only when in complete or failed state, otherwise API returns exception
    raw_status.first.end_with?("_COMPLETE", "_FAILED")
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
    ems.with_provider_connection(:service => "Orchestration") do |service|
      raw_stack = service.stacks.get(name, ems_ref)
      raise MiqException::MiqOrchestrationStackNotExistError, "#{name} does not exist on #{ems.name}" unless raw_stack

      # TODO(lsmola) implement Status class, like in Cloud Manager, or make it common superclass
      [raw_stack.stack_status, raw_stack.stack_status_reason]
    end
  rescue MiqException::MiqOrchestrationStackNotExistError
    raise
  rescue => err
    _log.error "stack=[#{name}], error: #{err}"
    raise MiqException::MiqOrchestrationStatusError, parse_error_message_from_fog_response(err), err.backtrace
  end

  def post_scaledown_task(services, task_id = nil)
    task = MiqTask.find(task_id) unless task_id.nil?
    if task && task.state == MiqTask::STATE_FINISHED && !MiqTask.status_ok?(task.status)
      raise MiqException::MiqQueueError, "Scaledown update failed, not running post scaledown task"
    end
    raise MiqException::MiqQueueRetryLater.new(:deliver_on => Time.now.utc + 1.minute) unless raw_status.first == 'UPDATE_COMPLETE'
    services.each(&:delete_service)
  end

  def raise_exception_if_stack_not_ready
    unless update_ready?
      raise MiqException::MiqQueueError, _("Provider stack is not ready to be updated, another operation is in progress.")
    end
  end

  def scale_down_queue(userid, stack_parameters, hosts)
    scale_queue('scale_down', userid, [stack_parameters, hosts])
  end

  def scale_down(stack_parameters, hosts)
    raise_exception_if_stack_not_ready
    if can_use_scale_down_workflow?
      # OSP >= 10 use workflows
      host_uuids_to_remove = hosts.map { |n| Host.find(n).uid_ems }
      scale_down_using_workflows(host_uuids_to_remove)
    else
      # OSP < 10 use heat stack update
      services = hosts.collect(&:cloud_services).flatten
      task_id = update_stack(nil, stack_parameters)
      post_scaledown_task(services, task_id)
    end
  end

  def scale_down_using_workflows(host_uuids_to_remove)
    ext_management_system.with_provider_connection(:service => "Workflow") do |service|
      input = { :container => name, :nodes => host_uuids_to_remove }
      info = service.execute_workflow("tripleo.scale.v1.delete_node", input)
      if info[1] == "SUCCESS"
        EmsRefresh.queue_refresh(ext_management_system)
      else
        raise MiqException::MiqOrchestrationUpdateError, info[3].body
      end
    end
  rescue => err
    log_and_raise_update_error(__method__, err)
  end

  def scale_up_queue(userid, stack_parameters)
    scale_queue('scale_up', userid, [stack_parameters])
  end

  def scale_up(stack_parameters)
    raise_exception_if_stack_not_ready
    if can_use_scale_up_workflow?
      # OSP >= 10 use workflows
      scale_up_using_workflows(stack_parameters)
    else
      # OSP < 10 use heat stack update
      update_stack(nil, stack_parameters)
    end
  end

  def scale_up_using_workflows(stack_parameters)
    ext_management_system.with_provider_connection(:service => "Workflow") do |service|
      info = service.execute_action("tripleo.parameters.update", :parameters => stack_parameters)
      raise MiqException::MiqOrchestrationUpdateError, info[3].body if info[1] != "SUCCESS"
      info = service.execute_workflow("tripleo.deployment.v1.deploy_plan", :container => name)
      if info[1] == "SUCCESS"
        EmsRefresh.queue_refresh(ext_management_system)
      else
        raise MiqException::MiqOrchestrationUpdateError, info[3].body
      end
    end
  rescue => err
    log_and_raise_update_error(__method__, err)
  end

  def self.display_name(number = 1)
    n_('Orchestration Stack (OpenStack)', 'Orchestration Stacks (OpenStack)', number)
  end

  private

  def scale_queue(method_name, userid, parameters)
    task_opts = {
      :action => "#{method_name} orchestration stack #{name} for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => method_name,
      :instance_id => id,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => parameters
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def log_and_raise_update_error(method_name, err)
    _log.error "MIQ(#{self}.#{method_name}) stack=[#{name}], error: #{err}"
    raise MiqException::MiqOrchestrationUpdateError, parse_error_message_from_fog_response(err), err.backtrace
  end

  def workflow_service
    ext_management_system.workflow_service
  end

  def can_use_scale_up_workflow?
    !workflow_service.nil? && workflow_service.has_action?("tripleo.parameters.update") && workflow_service.has_workflow?("tripleo.deployment.v1.deploy_plan")
  end

  def can_use_scale_down_workflow?
    !workflow_service.nil? && workflow_service.has_workflow?("tripleo.scale.v1.delete_node")
  end

  private :log_and_raise_update_error
end

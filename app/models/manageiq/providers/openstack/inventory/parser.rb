class ManageIQ::Providers::Openstack::Inventory::Parser < ManageIQ::Providers::Inventory::Parser
  def orchestration_stack_parameters(stack, stack_inventory_object)
    collector.orchestration_parameters(stack).each do |param_key, param_val|
      uid = compose_ems_ref(stack.id, param_key)
      o = persister.orchestration_stacks_parameters.find_or_build(uid)
      o.ems_ref = uid
      o.name = param_key
      o.value = param_val
      o.stack = stack_inventory_object
    end
  end

  def orchestration_stack_outputs(stack, stack_inventory_object)
    collector.orchestration_outputs(stack).each do |output|
      uid = compose_ems_ref(stack.id, output['output_key'])
      o = persister.orchestration_stacks_outputs.find_or_build(uid)
      o.ems_ref = uid
      o.key = output['output_key']
      o.value = output['output_value']
      o.description = output['description']
      o.stack = stack_inventory_object
    end
  end

  def orchestration_template(stack)
    template = collector.orchestration_template(stack)
    if template
      o = persister.orchestration_templates.find_or_build(stack.id)
      o.name = stack.stack_name
      o.description = stack.template.description
      o.content = stack.template.content
      o.orderable = false
      o
    end
  end

  private

  def compose_ems_ref(*keys)
    keys.join('_')
  end
end

module ManageIQ::Providers::Openstack::Inventory::Persister::Definitions::OrchestrationStackCollections
  extend ActiveSupport::Concern

  def add_orchestration_stack_collections
    add_orchestration_stacks_with_ems_param
    add_collection(cloud, :orchestration_stacks_resources)
    add_collection(cloud, :orchestration_stacks_outputs)
    add_collection(cloud, :orchestration_stacks_parameters)
    add_orchestration_templates
    add_orchestration_stack_ancestry
  end

  protected

  def add_orchestration_stacks(extra_properties = {})
    add_collection(cloud, :orchestration_stacks, extra_properties) do |builder|
      yield builder if block_given?
    end
  end

  def add_orchestration_templates
    add_collection(cloud, :orchestration_templates) do |builder|
      builder.add_properties(:model_class => ::OrchestrationTemplate)
    end
  end

  def add_orchestration_stack_ancestry
    add_collection(cloud, :orchestration_stack_ancestry) do |builder|
      builder.remove_dependency_attributes(:orchestration_stacks_resources) unless targeted?
    end
  end

  # Shortcut for better code readability
  def add_orchestration_stacks_with_ems_param
    add_orchestration_stacks do |builder|
      builder.add_default_values(:ems_id => manager.id)
    end
  end
end

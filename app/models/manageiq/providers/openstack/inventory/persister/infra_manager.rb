class ManageIQ::Providers::Openstack::Inventory::Persister::InfraManager < ManageIQ::Providers::Openstack::Inventory::Persister
  def initialize_inventory_collections
    add_collection(infra, :miq_templates) { |b| b.add_properties(:model_class => manager.class::Template) }
    add_collection(infra, :hardwares)
    add_collection(infra, :operating_systems)
    add_collection(infra, :clusters) { |b| b.add_properties(:model_class => manager.class::Cluster) }
    add_collection(infra, :orchestration_stacks)
    add_collection(infra, :hosts)
    add_collection(infra, :host_disks)
    add_collection(infra, :host_hardwares)
    add_collection(infra, :host_operating_systems)
    add_collection(cloud, :orchestration_stacks)
    add_collection(cloud, :orchestration_stacks_resources)
    add_collection(cloud, :orchestration_stacks_outputs)
    add_collection(cloud, :orchestration_stacks_parameters)
    add_collection(cloud, :orchestration_stack_ancestry)
    add_collection(cloud, :orchestration_templates)
  end
end

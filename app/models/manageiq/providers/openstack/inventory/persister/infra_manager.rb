class ManageIQ::Providers::Openstack::Inventory::Persister::InfraManager < ManageIQ::Providers::Openstack::Inventory::Persister
  def initialize_inventory_collections
    add_collection(infra, :miq_templates)
    add_collection(infra, :hardwares)
    add_collection(infra, :operating_systems)
    add_collection(infra, :clusters)
    add_collection(infra, :hosts)
    add_collection(infra, :host_disks)
    add_collection(infra, :host_hardwares)
    add_collection(infra, :host_operating_systems)
    add_collection(infra, :orchestration_stacks)
    add_collection(infra, :orchestration_stacks_resources)
    add_collection(infra, :orchestration_stacks_outputs)
    add_collection(infra, :orchestration_stacks_parameters)
    add_collection(cloud, :orchestration_templates)
    add_collection(infra, :orchestration_stack_ancestry)
  end
end

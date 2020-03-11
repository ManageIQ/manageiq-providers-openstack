class ManageIQ::Providers::Openstack::Inventory::Persister::InfraManager < ManageIQ::Providers::Openstack::Inventory::Persister
  def initialize_inventory_collections
    add_collection(infra, :miq_templates) { |b| b.add_properties(:model_class => manager.class::Template) }
    add_collection(infra, :hardwares)
    add_collection(infra, :operating_systems)
    add_collection(infra, :clusters)  { |b| b.add_properties(:model_class => manager.class::Cluster) }
    add_collection(infra, :orchestration_stacks)
    add_collection(infra, :hosts)
    add_collection(infra, :host_disks)
    add_collection(infra, :host_hardwares)
    add_collection(infra, :host_operating_systems)
    add_collection(infra, :orchestration_stacks)
    add_collection(infra, :orchestration_stacks_resources)
    add_collection(infra, :orchestration_stacks_outputs)
    add_collection(infra, :orchestration_stacks_parameters)
    add_collection(infra, :orchestration_templates)

    add_cloud_collection(:cloud_tenants)
  end

  private

  def add_cloud_collection(collection)
    add_collection(cloud, collection, shared_cloud_properties)
  end

  def cloud_manager
    manager.provider.cloud_ems.first
  end

  def shared_cloud_properties
    {:parent => cloud_manager, :strategy => :local_db_cache_all}
  end
end

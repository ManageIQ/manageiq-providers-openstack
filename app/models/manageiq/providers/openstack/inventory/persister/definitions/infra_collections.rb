module ManageIQ::Providers::Openstack::Inventory::Persister::Definitions::InfraCollections
  extend ActiveSupport::Concern

  include ManageIQ::Providers::Openstack::Inventory::Persister::Definitions::Utils

  def initialize_infra_inventory_collections
    add_miq_templates

    add_object_store

    add_hosts

    add_orchestration_stacks_with_ems_param

    %i(hardwares
       operating_systems
       disks
       orchestration_stacks_resources
       orchestration_stacks_outputs
       orchestration_stacks_parameters).each do |name|

      add_collection(infra, name)
    end

    add_clusters

    add_orchestration_templates(infra)

    add_cloud_tenants
  end

  # --- IC groups definitions ---

  def add_vms
    add_collection_with_ems_param(cloud, :vms) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::Openstack::InfraManager::Vm)
    end
  end

  def add_miq_templates
    add_collection(infra, :miq_templates) do |builder|
      builder.add_properties(:model_class => ::MiqTemplate)

      builder.add_default_values(:ems_id => manager.id)

      # Extra added to automatic attr ibutes
      builder.add_inventory_attributes(%i(cloud_tenant cloud_tenants))
    end
  end

  def add_hosts
    add_collection_with_ems_param(infra, :hosts) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::Openstack::InfraManager::Host)
    end
  end

  def add_object_store
    %i(cloud_object_store_objects
       cloud_object_store_containers).each do |name|
      add_collection(infra, name)
    end
  end

  def add_orchestration_stacks(extra_properties = {})
    add_collection(cloud, :orchestration_stacks, extra_properties) do |builder|
      yield builder if block_given?
    end
  end

  def add_clusters
    add_collection_with_ems_param(infra, :ems_clusters) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::Openstack::InfraManager::EmsCluster)
    end
  end

  def add_cloud_tenants
    add_collection_with_ems_param(cloud, :cloud_tenants) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::Openstack::InfraManager::CloudTenant)
    end
  end
end

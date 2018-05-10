module ManageIQ::Providers::Openstack::Inventory::Persister::Shared::CloudCollections
  extend ActiveSupport::Concern

  # Builder class for Cloud
  # TODO (mslemr) shared with amazon (maybe with all providers)
  def cloud
    ::ManagerRefresh::InventoryCollection::Builder::CloudManager
  end

  def initialize_cloud_inventory_collections
    %i(vms
       availability_zones
       cloud_tenants
       flavors).each do |name|

      add_collection_with_ems_param(cloud, name)
    end

    unless targeted?
      %i(cloud_resource_quotas
         cloud_services
         host_aggregates).each do |name|

        add_collection_with_ems_param(cloud, name)
      end
    end

    add_miq_templates

    add_key_pairs

    add_orchestration_stacks_with_ems_param

    %i(hardwares
       operating_systems
       disks
       networks
       orchestration_stacks_resources
       orchestration_stacks_outputs
       orchestration_stacks_parameters).each do |name|

      add_collection(cloud, name)
    end

    add_orchestration_templates

    add_vm_and_miq_template_ancestry

    add_orchestration_stack_ancestry
  end

  # ------ IC provider specific definitions -------------------------

  def add_miq_templates
    add_collection(cloud, :miq_templates) do |builder|
      builder.add_properties(:model_class => ::MiqTemplate)

      builder.add_builder_params(:ext_management_system => manager)

      # Added to automatic attributes
      builder.add_inventory_attributes(%i(cloud_tenant cloud_tenants))
    end
  end

  def add_orchestration_stacks(extra_properties = {})
    add_collection(cloud, :orchestration_stacks, extra_properties) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::CloudManager::OrchestrationStack)

      yield builder if block_given?
    end
  end

  def add_orchestration_templates
    add_collection(cloud, :orchestration_templates) do |builder|
      builder.add_properties(:model_class => ::OrchestrationTemplate)
    end
  end

  # TODO: mslemr - parent model class used anywhere?
  def add_key_pairs(extra_properties = {})
    add_collection(cloud, :key_pairs, extra_properties) do |builder|
      builder.add_properties(
        :model_class => ManageIQ::Providers::Openstack::CloudManager::AuthKeyPair,
      )

      builder.add_builder_params(:resource => manager) unless targeted?
    end
  end

  # TODO: mslemr - same as amazon!
  def add_vm_and_miq_template_ancestry
    add_collection(cloud, :vm_and_miq_template_ancestry, {}, {:auto_object_attributes => false, :auto_model_class => false, :without_model_class => true}) do |builder|
      builder.add_dependency_attributes(
        :vms           => [collections[:vms]],
        :miq_templates => [collections[:miq_templates]]
      )
    end
  end

  # TODO: mslemr - almost same as amazon!
  # Needed remove_dependency_attributes for core basic definition
  def add_orchestration_stack_ancestry
    add_collection(cloud, :orchestration_stack_ancestry, {}, {:auto_object_attributes => false, :auto_model_class => false, :without_model_class => true}) do |builder|
      builder.add_dependency_attributes(
        :orchestration_stacks => [collections[:orchestration_stacks]]
      )

      if targeted?
        builder.add_dependency_attributes(
          :orchestration_stacks_resources => [collections[:orchestration_stacks_resources]]
        )
      end
    end
  end

  private

  # Shortcut for better code readability
  def add_collection_with_ems_param(builder_class, collection_name, extra_properties = {})
    add_collection(builder_class, collection_name, extra_properties) do |builder|
      builder.add_builder_params(:ext_management_system => manager)
    end
  end

  # Shortcut for better code readability
  def add_orchestration_stacks_with_ems_param
    add_orchestration_stacks do |builder|
      builder.add_builder_params(:ext_management_system => manager)
    end
  end
end

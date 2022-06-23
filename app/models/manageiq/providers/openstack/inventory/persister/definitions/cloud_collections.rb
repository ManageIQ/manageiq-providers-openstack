module ManageIQ::Providers::Openstack::Inventory::Persister::Definitions::CloudCollections
  extend ActiveSupport::Concern

  include ManageIQ::Providers::Openstack::Inventory::Persister::Definitions::OrchestrationStackCollections

  # used also in ovirt, so automatic model_classes are not possible in many cases
  def initialize_cloud_inventory_collections
    add_vms
    add_miq_templates
    add_auth_key_pairs
    add_orchestration_stacks
    add_orchestration_templates

    add_cloud_collection(:orchestration_stacks_resources)
    add_cloud_collection(:orchestration_stacks_outputs)
    add_cloud_collection(:orchestration_stacks_parameters)
    add_cloud_collection(:availability_zones)
    add_cloud_collection(:cloud_tenants)
    add_cloud_collection(:flavors)
    add_cloud_collection(:hardwares)
    add_cloud_collection(:operating_systems)
    add_cloud_collection(:placement_groups)
    add_cloud_collection(:disks)
    add_cloud_collection(:snapshots)
    add_cloud_collection(:networks)

    unless targeted?
      add_cloud_collection(:cloud_resource_quotas)
      add_cloud_collection(:cloud_services)
      add_cloud_collection(:host_aggregates)
    end

    # Custom processing of Ancestry
    add_cloud_collection(:vm_and_miq_template_ancestry)
    add_orchestration_stack_ancestry

    add_vm_and_template_labels
    add_vm_and_template_taggings
  end

  # ------ IC provider specific definitions -------------------------

  def add_vms
    add_cloud_collection(:vms) do |builder|
      builder.add_default_values(:vendor => manager.class.vm_vendor)
    end
  end

  def add_miq_templates
    add_cloud_collection(:miq_templates) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::Openstack::CloudManager::BaseTemplate)
      builder.add_default_values(:vendor => manager.class.vm_vendor)

      # Extra added to automatic attributes
      builder.add_inventory_attributes(%i(cloud_tenant cloud_tenants))
    end
  end

  def add_orchestration_stacks(extra_properties = {})
    add_cloud_collection(:orchestration_stacks, extra_properties) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::CloudManager::OrchestrationStack)

      yield builder if block_given?
    end
  end

  def add_auth_key_pairs(extra_properties = {})
    add_collection(cloud, :auth_key_pairs, extra_properties) do |builder|
      # targeted refresh workaround-- always refresh the whole keypair collection
      # regardless of whether this is a TargetCollection or not
      # because OpenStack doesn't give us UUIDs of changed keypairs,
      # we just get an event that one of them changed
      builder.add_properties(:targeted => false) if references(:key_pairs).present?
      builder.add_default_values(:resource => manager)
    end
  end

  def add_vm_and_template_labels
    add_collection(cloud, :vm_and_template_labels) do |builder|
      builder.add_targeted_arel(
        lambda do |inventory_collection|
          manager_uuids = inventory_collection.parent_inventory_collections.collect(&:manager_uuids).map(&:to_a).flatten
          inventory_collection.parent.vm_and_template_labels.where(
            'vms' => {:ems_ref => manager_uuids}
          )
        end
      )
    end
  end

  def add_vm_and_template_taggings
    add_collection(cloud, :vm_and_template_taggings) do |builder|
      builder.add_properties(
        :model_class                  => Tagging,
        :manager_ref                  => %i(taggable tag),
        :parent_inventory_collections => %i(vms miq_templates)
      )

      builder.add_targeted_arel(
        lambda do |inventory_collection|
          manager_uuids = inventory_collection.parent_inventory_collections.collect(&:manager_uuids).map(&:to_a).flatten
          ems = inventory_collection.parent
          ems.vm_and_template_taggings.where(
            'taggable_id' => ems.vms_and_templates.where(:ems_ref => manager_uuids)
          )
        end
      )
    end
  end
end

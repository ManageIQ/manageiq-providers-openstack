module ManageIQ::Providers::Openstack::Inventory::Persister::Definitions::CloudCollections
  extend ActiveSupport::Concern

  include ManageIQ::Providers::Openstack::Inventory::Persister::Definitions::Utils

  # used also in ovirt, so automatic model_classes are not possible in many cases
  def initialize_cloud_inventory_collections
    add_vms

    add_miq_templates

    add_availability_zones

    add_cloud_tenants

    add_flavors

    add_key_pairs

    unless targeted?
      add_cloud_resource_quotas

      add_cloud_services

      add_host_aggregates
    end

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

    # Custom processing of Ancestry
    add_collection(cloud, :vm_and_miq_template_ancestry)

    add_orchestration_stack_ancestry

    add_snapshots

    add_vm_and_template_labels
    add_vm_and_template_taggings
  end

  # ------ IC provider specific definitions -------------------------

  # model_class defined due to ovirt dependency
  def add_vms
    add_collection_with_ems_param(cloud, :vms) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::Openstack::CloudManager::Vm)
    end
  end

  def add_miq_templates
    add_collection(cloud, :miq_templates) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::Openstack::CloudManager::BaseTemplate)
      builder.add_default_values(:ems_id => manager.id)

      # Extra added to automatic attributes
      builder.add_inventory_attributes(%i(cloud_tenant cloud_tenants))
    end
  end

  # model_class defined due to ovirt dependency
  def add_availability_zones
    add_collection_with_ems_param(cloud, :availability_zones) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::Openstack::CloudManager::AvailabilityZone)
    end
  end

  # model_class defined due to ovirt dependency
  def add_cloud_tenants
    add_collection_with_ems_param(cloud, :cloud_tenants) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::Openstack::CloudManager::CloudTenant)
    end
  end

  # model_class defined due to ovirt dependency
  def add_flavors
    add_collection_with_ems_param(cloud, :flavors) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::Openstack::CloudManager::Flavor)
    end
  end

  # model_class defined due to ovirt dependency
  def add_cloud_resource_quotas
    add_collection_with_ems_param(cloud, :cloud_resource_quotas) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::Openstack::CloudManager::CloudResourceQuota)
    end
  end

  def add_cloud_services
    add_collection_with_ems_param(cloud, :cloud_services)
  end

  # model_class defined due to ovirt dependency
  def add_host_aggregates
    add_collection_with_ems_param(cloud, :host_aggregates) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::Openstack::CloudManager::HostAggregate)
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

  def add_key_pairs(extra_properties = {})
    add_collection(cloud, :key_pairs, extra_properties) do |builder|
      builder.add_properties(
        :model_class => ManageIQ::Providers::Openstack::CloudManager::AuthKeyPair,
      )
      # targeted refresh workaround-- always refresh the whole keypair collection
      # regardless of whether this is a TargetCollection or not
      # because OpenStack doesn't give us UUIDs of changed keypairs,
      # we just get an event that one of them changed
      if references(:key_pairs).present?
        builder.add_properties(:targeted => false)
      end
      builder.add_default_values(:resource => manager)
    end
  end

  def add_orchestration_stack_ancestry
    add_collection(cloud, :orchestration_stack_ancestry) do |builder|
      builder.remove_dependency_attributes(:orchestration_stacks_resources) unless targeted?
    end
  end

  def add_snapshots
    add_collection(cloud, :snapshots) do |builder|
      builder.add_properties(:model_class => ::Snapshot)
      builder.add_properties(:parent_inventory_collections => %i[vms miq_templates])
      builder.add_properties(:complete => !targeted?)
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

  protected

  # Shortcut for better code readability
  def add_orchestration_stacks_with_ems_param
    add_orchestration_stacks do |builder|
      builder.add_default_values(:ems_id => manager.id)
    end
  end
end

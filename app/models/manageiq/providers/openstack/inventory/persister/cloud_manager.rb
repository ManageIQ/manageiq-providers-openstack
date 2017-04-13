class ManageIQ::Providers::Openstack::Inventory::Persister::CloudManager < ManagerRefresh::Inventory::Persister
  def cloud
    ManageIQ::Providers::Openstack::InventoryCollectionDefault::CloudManager
  end

  def initialize_inventory_collections
    add_inventory_collections(
      cloud,
      %i(
        availability_zones
        cloud_resource_quotas
        cloud_services
        cloud_tenants
        flavors
        host_aggregates
        miq_templates
        orchestration_stacks
        vms
      ),
      :builder_params => {:ext_management_system => manager}
    )

    add_inventory_collections(
      cloud,
      %i(
        key_pairs
      ),
      :builder_params => {:resource => manager}
    )

    add_inventory_collections(
      cloud,
      %i(
        hardwares
        disks
        networks
        orchestration_templates
        orchestration_stacks_resources
        orchestration_stacks_outputs
        orchestration_stacks_parameters
      )
    )

    add_inventory_collection(
      cloud.vm_and_miq_template_ancestry(
        :dependency_attributes => {
          :vms           => [collections[:vms]],
          :miq_templates => [collections[:miq_templates]]
        }
      )
    )

    add_inventory_collection(
      cloud.orchestration_stack_ancestry(
        :dependency_attributes => {
          :orchestration_stacks => [collections[:orchestration_stacks]],
        }
      )
    )
  end
end

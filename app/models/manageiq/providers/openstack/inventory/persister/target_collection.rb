class ManageIQ::Providers::Openstack::Inventory::Persister::TargetCollection < ManageIQ::Providers::Openstack::Inventory::Persister
  def initialize_inventory_collections
    ######### Cloud ##########
    # Top level models with direct references for Cloud
    add_inventory_collections_with_references(
      cloud,
      %i(vms miq_templates availability_zones orchestration_stacks cloud_tenants flavors),
      :builder_params => {:ext_management_system => manager}
    )

    add_inventory_collection_with_references(
      cloud,
      :key_pairs,
      name_references(:key_pairs)
    )

    # Child models with references in the Parent InventoryCollections for Cloud
    add_inventory_collections(
      cloud,
      %i(hardwares operating_systems networks disks orchestration_stacks_resources
         orchestration_stacks_outputs orchestration_stacks_parameters),
      :strategy => strategy,
      :targeted => true
    )

    add_inventory_collection(cloud.orchestration_templates)

    ######## Networking ########
    add_inventory_collections_with_references(
      network,
      %i(cloud_networks cloud_subnets security_groups floating_ips network_ports network_routers),
      :parent => manager.network_manager
    )

    add_inventory_collections(
      network,
      %i(
        cloud_subnet_network_ports firewall_rules
      ),
      :strategy => strategy,
      :targeted => true,
      :parent   => manager.network_manager
    )

    ######## Custom processing of Ancestry ##########
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
          :orchestration_stacks           => [collections[:orchestration_stacks]],
          :orchestration_stacks_resources => [collections[:orchestration_stacks_resources]]
        }
      )
    )
  end

  private

  def add_inventory_collections_with_references(inventory_collections_data, names, options = {})
    names.each do |name|
      add_inventory_collection_with_references(inventory_collections_data, name, references(name), options)
    end
  end

  def add_inventory_collection_with_references(inventory_collections_data, name, manager_refs, options = {})
    options = inventory_collections_data.send(
      name,
      :manager_uuids => manager_refs,
      :strategy      => strategy,
      :targeted      => true
    ).merge(options)

    add_inventory_collection(options)
  end

  def strategy
    :local_db_find_missing_references
  end

  def references(collection)
    target.manager_refs_by_association.try(:[], collection).try(:[], :ems_ref).try(:to_a) || []
  end

  def name_references(collection)
    target.manager_refs_by_association.try(:[], collection).try(:[], :name).try(:to_a) || []
  end

  def cloud
    ManageIQ::Providers::Openstack::InventoryCollectionDefault::CloudManager
  end

  def network
    ManageIQ::Providers::Openstack::InventoryCollectionDefault::NetworkManager
  end
end

module ManageIQ::Providers
  class Openstack::CloudManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
    def save_inventory(ems, target, inventory_collections)
      super
      EmsRefresh.queue_refresh(ems.network_manager) if target.kind_of?(ManageIQ::Providers::BaseManager)
      EmsRefresh.queue_refresh(ems.cinder_manager) if target.kind_of?(ManageIQ::Providers::BaseManager)
      EmsRefresh.queue_refresh(ems.swift_manager) if target.kind_of?(ManageIQ::Providers::BaseManager)
    end

    def preprocess_targets
      super

      # sort the EMSes to be refreshed with cloud managers before other EMSes.
      # since @targets_by_ems_id is a hash, we have to insert the items into a new
      # hash in the order we want them to appear.
      sorted_ems_targets = {}
      # pull out the IDs of cloud managers and reinsert them in a new hash first, to take advantage of preserved insertion order
      cloud_manager_ids = @targets_by_ems_id.keys.select { |key| @ems_by_ems_id[key].kind_of? ManageIQ::Providers::Openstack::CloudManager }
      cloud_manager_ids.each { |ems_id| sorted_ems_targets[ems_id] = @targets_by_ems_id.delete(ems_id) }
      # now that the cloud managers have been removed from @targets_by_ems_id, move the rest of the values
      # over to the new hash and then replace @targets_by_ems_id.
      @targets_by_ems_id.keys.each { |ems_id| sorted_ems_targets[ems_id] = @targets_by_ems_id.delete(ems_id) }
      @targets_by_ems_id = sorted_ems_targets
    end

    def post_process_refresh_classes
      [::Vm, CloudTenant]
    end
  end
end

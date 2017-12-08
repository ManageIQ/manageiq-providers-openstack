module ManageIQ::Providers
  class Openstack::CloudManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
    include ::EmsRefresh::Refreshers::EmsRefresherMixin

    def collect_inventory_for_targets(ems, targets)
      targets_with_data = targets.collect do |target|
        target_name = target.try(:name) || target.try(:event_type)

        _log.info("Filtering inventory for #{target.class} [#{target_name}] id: [#{target.id}]...")
        if ::Settings.ems.ems_refresh.openstack.try(:inventory_object_refresh)
          inventory = ManageIQ::Providers::Openstack::Builder.build_inventory(ems, target)
        end

        _log.info("Filtering inventory...Complete")
        [target, inventory]
      end

      targets_with_data
    end

    def parse_legacy_inventory(ems)
      ManageIQ::Providers::Openstack::CloudManager::RefreshParser.ems_inv_to_hashes(ems, refresher_options)
    end

    def save_inventory(ems, target, inventory_collections)
      super
      EmsRefresh.queue_refresh(ems.network_manager) if target.kind_of?(ManageIQ::Providers::BaseManager)
      EmsRefresh.queue_refresh(ems.cinder_manager) if target.kind_of?(ManageIQ::Providers::BaseManager)
      EmsRefresh.queue_refresh(ems.swift_manager) if target.kind_of?(ManageIQ::Providers::BaseManager)
    end

    def parse_targeted_inventory(ems, _target, inventory)
      log_header = format_ems_for_logging(ems)
      _log.debug("#{log_header} Parsing inventory...")
      hashes, = Benchmark.realtime_block(:parse_inventory) do
        if ::Settings.ems.ems_refresh.openstack.try(:inventory_object_refresh)
          inventory.inventory_collections
        else
          ManageIQ::Providers::Openstack::CloudManager::RefreshParser.ems_inv_to_hashes(ems, refresher_options)
        end
      end
      _log.debug("#{log_header} Parsing inventory...Complete")

      hashes
    end

    def preprocess_targets
      @targets_by_ems_id.each do |ems_id, targets|
        if targets.any? { |t| t.kind_of?(ExtManagementSystem) }
          ems             = @ems_by_ems_id[ems_id]
          targets_for_log = targets.map { |t| "#{t.class} [#{t.name}] id [#{t.id}] " }
          _log.info("Defaulting to full refresh for EMS: [#{ems.name}], id: [#{ems.id}], from targets: #{targets_for_log}") if targets.length > 1
        end

        # We want all targets of class EmsEvent to be merged into one target,
        # so they can be refreshed together, otherwise we could be missing some
        # crosslinks in the refreshed data
        all_targets, sub_ems_targets = targets.partition { |x| x.kind_of?(ExtManagementSystem) }

        unless sub_ems_targets.blank?
          if ::Settings.ems.ems_refresh.openstack.try(:allow_targeted_refresh)
            # We can disable targeted refresh with a setting, then we will just do full ems refresh on any event
            ems_event_collection = ManagerRefresh::TargetCollection.new(:targets    => sub_ems_targets,
                                                                        :manager_id => ems_id)
            all_targets << ems_event_collection
          else
            all_targets << @ems_by_ems_id[ems_id]
          end
        end

        @targets_by_ems_id[ems_id] = all_targets
      end

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

      super
    end

    def post_process_refresh_classes
      [::Vm, CloudTenant]
    end
  end
end

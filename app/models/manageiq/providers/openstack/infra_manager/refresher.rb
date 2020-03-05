module ManageIQ
  module Providers
    class Openstack::InfraManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
      def parse_legacy_inventory(ems)
        ManageIQ::Providers::Openstack::InfraManager::RefreshParser.ems_inv_to_hashes(ems, refresher_options)
      end

      # TODO(lsmola) NetworkManager, remove this once we have a full representation of the NetworkManager.
      # NetworkManager should refresh base on it;s own conditions
      def save_inventory(ems, target, hashes)
        super
        EmsRefresh.queue_refresh(ems.network_manager)
      end

      def collect_inventory_for_targets(ems, _targets)
        [[ems, nil]]
      end

      def parse_targeted_inventory(ems, _target, _inventory)
        log_header = format_ems_for_logging(ems)
        _log.debug("#{log_header} Parsing inventory...")
        hashes = ems.class::RefreshParser.ems_inv_to_hashes(ems, refresher_options)
        _log.debug("#{log_header} Parsing inventory...Complete")
        hashes
      end

      def preprocess_targets_manager_refresh
      end

      def post_process_refresh_classes
        [::Vm, ManageIQ::Providers::Openstack::InfraManager::Host]
      end
    end
  end
end

module ManageIQ
  module Providers
    class Openstack::InfraManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
      # TODO(lsmola) NetworkManager, remove this once we have a full representation of the NetworkManager.
      # NetworkManager should refresh base on it;s own conditions
      def save_inventory(ems, target, hashes)
        super
        EmsRefresh.queue_refresh(ems.network_manager)
      end

      def post_process_refresh_classes
        [::Vm, ManageIQ::Providers::Openstack::InfraManager::Host]
      end
    end
  end
end

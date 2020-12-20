module ManageIQ::Providers
  class Openstack::StorageManager::SwiftManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
    def post_process_refresh_classes
      []
    end

    # Legacy parse
    #
    # @param ems [ManageIQ::Providers::BaseManager]
    def parse_legacy_inventory(ems)
      ::ManageIQ::Providers::Openstack::StorageManager::SwiftManager::RefreshParser.ems_inv_to_hashes(ems)
    end
  end
end

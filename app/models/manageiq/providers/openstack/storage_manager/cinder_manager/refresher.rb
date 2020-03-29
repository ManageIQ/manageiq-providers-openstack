module ManageIQ::Providers
  class Openstack::StorageManager::CinderManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
    def post_process_refresh_classes
      []
    end
  end
end

module ManageIQ::Providers
  class Openstack::NetworkManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
    def post_process_refresh_classes
      []
    end
  end
end

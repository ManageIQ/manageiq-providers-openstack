module ManageIQ::Providers
  class Openstack::NetworkManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
    include ::EmsRefresh::Refreshers::EmsRefresherMixin

    def parse_legacy_inventory(ems)
      ManageIQ::Providers::Openstack::NetworkManager::RefreshParser.ems_inv_to_hashes(ems, refresher_options)
    end

    def parse_targeted_inventory(ems, target, collector)
      if ::Settings.ems.ems_openstack.refresh.inventory_object_refresh
        super(ems, target, collector)
      else
        super(ems, target, nil)
      end
    end

    def post_process_refresh_classes
      []
    end
  end
end

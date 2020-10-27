module ManageIQ::Providers::Openstack::NetworkManagerMixin
  extend ActiveSupport::Concern
  include ::HasNetworkManagerMixin

  included do
    has_one  :network_manager,
             :foreign_key => :parent_ems_id,
             :class_name  => "ManageIQ::Providers::Openstack::NetworkManager",
             :autosave    => true
  end
end

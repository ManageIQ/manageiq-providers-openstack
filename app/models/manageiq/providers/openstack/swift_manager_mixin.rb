module ManageIQ::Providers::Openstack::SwiftManagerMixin
  extend ActiveSupport::Concern
  include ::SwiftManagerMixin

  included do
    has_one  :swift_manager,
             :foreign_key => :parent_ems_id,
             :class_name  => "ManageIQ::Providers::Openstack::SwiftManager",
             :autosave    => true,
             :dependent   => :destroy

    delegate :cloud_object_store_containers,
             :cloud_object_store_objects,
             :to        => :swift_manager,
             :allow_nil => true
  end
end

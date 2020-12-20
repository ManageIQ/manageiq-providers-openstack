module ManageIQ::Providers::Openstack::SwiftManagerMixin
  extend ActiveSupport::Concern
  include ::SwiftManagerMixin

  included do
    # TODO: how about many storage managers???
    # Should use has_many :storage_managers,
    has_one :swift_manager,
            :dependent,
            :foreign_key => :parent_ems_id,
            :inverse_of  => false,
            :class_name  => "ManageIQ::Providers::StorageManager::SwiftManager",
            :autosave    => true

    delegate :cloud_object_container,
             :cloud_object_object,
             :to        => :swift_manager,
             :allow_nil => true
  end
end

module ManageIQ::Providers::Openstack::SwiftManagerMixin
  extend ActiveSupport::Concern
  include ::SwiftManagerMixin

  included do
    has_one  :swift_manager,
             :foreign_key => :parent_ems_id,
             :class_name  => "ManageIQ::Providers::StorageManager::SwiftManager",
             :autosave    => true
  end
end

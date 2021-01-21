module ManageIQ::Providers::Openstack::CinderManagerMixin
  extend ActiveSupport::Concern

  included do
    # TODO: how about many storage managers???
    # Should use has_many :storage_managers,
    has_one  :cinder_manager,
             :foreign_key => :parent_ems_id,
             :class_name  => "ManageIQ::Providers::Openstack::StorageManager::CinderManager",
             :autosave    => true

    delegate :cloud_volumes,
             :cloud_volume_snapshots,
             :cloud_volume_backups,
             :cloud_volume_types,
             :to        => :cinder_manager,
             :allow_nil => true
  end
end

class ManageIQ::Providers::Openstack::StorageManager::CinderManager::EventCatcher < ::MiqEventCatcher
  include ManageIQ::Providers::Openstack::EventCatcherMixin

  def self.settings_name
    :event_catcher_openstack_cinder
  end
end

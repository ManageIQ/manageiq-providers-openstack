class ManageIQ::Providers::Openstack::NetworkManager::EventCatcher < ::MiqEventCatcher
  include ManageIQ::Providers::Openstack::EventCatcherMixin

  require_nested :Runner

  def self.settings_name
    :event_catcher_openstack_network
  end
end

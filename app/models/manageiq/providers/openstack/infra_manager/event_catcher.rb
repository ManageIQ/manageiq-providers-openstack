class ManageIQ::Providers::Openstack::InfraManager::EventCatcher < ::MiqEventCatcher
  include ManageIQ::Providers::Openstack::EventCatcherMixin

  require_nested :Runner

  def self.settings_name
    :event_catcher_openstack_infra
  end
end

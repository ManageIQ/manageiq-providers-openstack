class ManageIQ::Providers::Openstack::CloudManager::EventCatcher < ::MiqEventCatcher
  include ManageIQ::Providers::Openstack::EventCatcherMixin

  require_nested :Runner
end

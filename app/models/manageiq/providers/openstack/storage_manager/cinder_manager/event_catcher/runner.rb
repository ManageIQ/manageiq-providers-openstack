class ManageIQ::Providers::Openstack::StorageManager::CinderManager::EventCatcher::Runner < ManageIQ::Providers::BaseManager::EventCatcher::Runner
  include ManageIQ::Providers::Openstack::EventCatcherRunnerMixin

  def add_openstack_queue(event)
    event_hash = ManageIQ::Providers::Openstack::StorageManager::CinderManager::EventParser.event_to_hash(event, @cfg[:ems_id])
    EmsEvent.add_queue('add', @cfg[:ems_id], event_hash)
  end
end

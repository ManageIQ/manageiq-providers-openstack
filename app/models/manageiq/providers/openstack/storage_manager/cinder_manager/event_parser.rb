module ManageIQ::Providers::Openstack::StorageManager::CinderManager::EventParser
  def self.event_to_hash(event, ems_id)
    ManageIQ::Providers::Openstack::CloudManager::EventParser.event_to_hash(event, ems_id)
  end
end

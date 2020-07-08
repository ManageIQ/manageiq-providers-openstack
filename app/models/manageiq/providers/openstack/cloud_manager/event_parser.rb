module ManageIQ::Providers::Openstack::CloudManager::EventParser
  def self.event_to_hash(event, ems_id)
    ManageIQ::Providers::Openstack::EventParserCommon.event_to_hash(event, ems_id) do |event_hash, payload|
      event_hash[:vm_ems_ref]                = payload["instance_id"]       if payload.key? "instance_id"
      event_hash[:host_ems_ref]              = payload["host"]              if payload.key? "host"
      event_hash[:availability_zone_ems_ref] = payload["availability_zone"] if payload.key? "availability_zone"
      event_hash[:chain_id]                  = payload["reservation_id"]    if payload.key? "reservation_id"
    end
  end
end

module ManageIQ::Providers::Openstack::InfraManager::EventParser
 def self.event_to_hash(event, ems_id)
    ManageIQ::Providers::Openstack::EventParserCommon.event_to_hash(event, ems_id) do |event_hash, payload|
      if payload.key? "instance_id"
        event_hash[:host_uid_ems] = payload["instance_id"]
        event_hash[:host_name]    = payload["instance_id"]
      end
      event_hash[:message]                   = payload["message"]           if payload.key? "message"
      event_hash[:host_ems_ref]              = payload["node"]              if payload.key? "node"
      event_hash[:availability_zone_ems_ref] = payload["availability_zone"] if payload.key? "availability_zone"
      event_hash[:chain_id]                  = payload["reservation_id"]    if payload.key? "reservation_id"
    end
  end
end

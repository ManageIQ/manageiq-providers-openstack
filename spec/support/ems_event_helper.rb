def create_ems_event(manager, event_type, oslo_message, payload)
  full_data =
    if oslo_message
      {:content => {'oslo.message' => {'payload' => payload}.to_json}}
    else
      {:content => {'payload' => payload}}
    end

  event_hash = {
    :event_type => event_type,
    :message    => payload,
    :timestamp  => "2016-03-13T16:59:01.760000",
    :username   => "",
    :full_data  => full_data,
    :ems_id     => manager.id
  }
  EmsEvent.add(manager.id, event_hash)
end

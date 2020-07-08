module ManageIQ::Providers::Openstack::EventParserCommon
  def self.event_to_hash(event, ems_id)
    content = message_content(event)
    event_type = content["event_type"]
    payload = content.fetch("payload", {})

    log_header = "ems_id: [#{ems_id}] " unless ems_id.nil?
    _log.debug("#{log_header}event: [#{event_type}]") if $log && $log.debug?

    # attributes that are common to all notifications
    event_hash = {
      :event_type => event_type,
      :source     => "OPENSTACK",
      :message    => payload,
      :timestamp  => content["timestamp"],
      :username   => content["_context_user_name"],
      :full_data  => event,
      :ems_id     => ems_id
    }

    yield(event_hash, payload) if block_given?

    event_hash
  end

  def self.message_content(event)
    # If this is an EmsEvent record, pull out the full_data
    event = event.full_data if event.respond_to?(:full_data)

    if (oslo_message = event.fetch_path(:content, 'oslo.message'))
      begin
        JSON.parse(oslo_message)
      rescue JSON::ParserError
        {}
      end
    else
      event.fetch(:content, {})
    end
  end
end

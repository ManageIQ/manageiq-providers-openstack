class OpenstackStfEventConverter
  def initialize(event)
    @event = event.symbolize_keys
    @event_payload = @event.fetch(:payload).symbolize_keys
    @payload = hashize_traits(@event_payload.fetch(:traits))
  end

  def metadata
    {:user_id => nil, :priority => nil, :content_type => nil}
  end

  def payload
    {
      "message_id" => @event_payload.fetch(:message_id),
      "event_type" => @event_payload.fetch(:event_type),
      "timestamp"  => @event_payload.fetch(:generated),
      "payload"    => @payload,
    }
  end

  private

  def hashize_traits(traits_list)
    output = {}
    traits_list.each do |trait_elem|
      output[trait_elem.first] = trait_elem.last
    end
    output
  end
end

require 'qpid_proton'

class OpenStackStfEventReceiver < Qpid::Proton::MessagingHandler
  def initialize(url, topic, received_events_block)
    super()
    @topic                 = topic
    @url                   = url
    @received_events_block = received_events_block
  end

  def on_container_start(container)
    c = container.connect(@url)
    c.open_receiver(@topic)
  end

  def on_message(_delivery, message)
    @received_events_block.call(message.body)
  end

  def on_error(err)
    $log.error("STF Event Receiver error: #{err.inspect}") if $log
    raise err
  end
end

require 'qpid_proton'

class OpenStackSafEventReceiver < Qpid::Proton::MessagingHandler

  def initialize(url, topic, received_events_block)
    puts "SAF RECEIVER INIT"
    super()
    @topic                 = topic
    @url                   = url
    @received_events_block = received_events_block
  end

  def on_container_start(container)
    c = container.connect(@url)
    c.open_receiver(@topic)
  end

  def on_message(delivery, message)
    puts "SAF RECEIVER MESSAGE"
    p message
    @received_events_block.call(message)
  end
end
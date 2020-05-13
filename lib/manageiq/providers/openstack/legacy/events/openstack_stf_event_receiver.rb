require 'qpid_proton'

class OpenStackStfEventReceiver < Qpid::Proton::MessagingHandler

  def initialize(url, topic, received_events_block, events_mutex)
    puts "STF RECEIVER INIT"
    super()
    @topic                 = topic
    @url                   = url
    @received_events_block = received_events_block
    @events_mutex          = events_mutex
  end

  def on_container_start(container)
    puts "STF starting.."
    c = container.connect(@url)
    c.open_receiver(@topic)
  end

  def on_message(delivery, message)
    puts "STF RECEIVER MESSAGE"
    p message
    @events_mutex.synchronize do 
      @received_events_block.call(message.body)
    end
  end
end
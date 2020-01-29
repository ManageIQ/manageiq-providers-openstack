require 'qpid_proton'

class OpenStackSafEventReceiver < Qpid::Proton::MessagingHandler

  def initialize(url, topic, received_events, received_events_mutex)
    puts "SAF RECEIVER INIT"
    super()
    @topic                 = topic
    @url                   = url
    @received_events       = received_events
    @received_events_mutex = received_events_mutex
  end

  def on_container_start(container)
    c = container.connect(@url)
    c.open_receiver(@topic)
  end

  def on_message(delivery, message)
    puts "SAF RECEIVER MESSAGE"
    @received_events_mutex.synchronize do
      @events << message.body
    end
  end
end
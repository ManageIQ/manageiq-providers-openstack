require 'qpid_proton'

class OpenStackStfEventTestReceiver < Qpid::Proton::MessagingHandler

  def initialize(url, topic)
    puts "STF test RECEIVER INIT"
    super()
    @topic                 = topic
    @url                   = url
  end

  def on_container_start(container)
    puts "STF testing.."
    c = container.connect(@url)
    c.open_receiver(@topic)
    # If the open_receiver passed, container can be closed to make the test successful
    c.close
  end
end

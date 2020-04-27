require 'manageiq/providers/openstack/legacy/openstack_event_monitor'
require 'manageiq/providers/openstack/legacy/events/openstack_event'
require 'manageiq/providers/openstack/legacy/events/openstack_stf_event_receiver'
require 'qpid_proton'

class OpenstackStfEventMonitor < OpenstackEventMonitor
  DEFAULT_AMQP_PORT  = 5666
  DEFAULT_TOPIC_NAME = 'anycast/ceilometer/event.sample'

  # SAF/QDR event monitor is available if a connection can be established.
  def self.available?(options = {})
    $log.info("Testing connection to STF..") if $log
    qdr_client = Qpid::Proton::Container.new.connect(build_qdr_client_url(options))
    qdr_client.close
    return true
  rescue => ex
    $log.info("OpenstackSTFEventMonitor availability check failed with #{ex}.") if $log
    false
  end

  def self.plugin_priority
    1
  end

  def self.build_qdr_client_url(options)
    $log.info("Building STF QDR client connection with #{options.inspect}..") if $log
    protocol = options[:security_protocol].to_s.start_with?('ssl') ? 'amqps' : 'amqp'
    hostname = options[:hostname]
    port     = options[:port] || DEFAULT_AMQP_PORT
    #TODO: add other needed parameters like auth/credentials
    "#{protocol}://#{hostname}:#{port}"
  end

  def initialize(options = {})
    $log.info("Building STF QDR client INIT #{options.inspect}..") if $log
    @options = options
    @ems = options[:ems]

    @collecting_events = false
    @events = []
    @events_mutex = Mutex.new

    @recv_block = ->(event) { puts "ev in recv_block"; @events << event }
    
    @qdr_receiver_thread = nil
  end

  def start
    $log.info("Building STF QDR client START..") if $log
    @qdr_receiver = Qpid::Proton::Container.new(OpenStackStfEventReceiver.new(self.class.build_qdr_client_url(@options), DEFAULT_TOPIC_NAME, @recv_block, @events_mutex))
    @handler = Thread.start { @qdr_receiver.run }
  end

  def stop
    $log.info("Building STF QDR client STOP..") if $log
    @qdr_receiver&.container&.stop
    @handler&.terminate!
  end

  def each_batch
    $log.info("Building STF QDR client EACHBATCH..") if $log
    @collecting_events = true
    while @collecting_events
      @events_mutex.synchronize do
        $log.info("MIQ(#{self.class.name}) STF Yielding #{@events.size} events to"\
                   " event_catcher: #{@events.map { |e| e.payload }}") if $log
                   
              #??     openstack_event(nil, converted_event.metadata, converted_event.payload)
        yield @events
        $log.info("MIQ(#{self.class.name}) Clearing events") if $log
        @events.clear
      end
      sleep 5
    end
  end

  def each
    each_batch do |events|
      events.each { |e| yield e }
    end
  end
end

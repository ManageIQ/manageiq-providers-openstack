require 'manageiq/providers/openstack/legacy/openstack_event_monitor'
require 'manageiq/providers/openstack/legacy/events/openstack_event'
require 'manageiq/providers/openstack/legacy/events/openstack_stf_event_converter'
require 'manageiq/providers/openstack/legacy/events/openstack_stf_event_receiver'
require 'manageiq/providers/openstack/legacy/events/openstack_stf_event_test_receiver'
require 'qpid_proton'

class OpenstackStfEventMonitor < OpenstackEventMonitor
  DEFAULT_AMQP_PORT  = 5666
  DEFAULT_TOPIC_NAME = 'anycast/ceilometer/event.sample'

  def self.available?(options = {})
    $log.info("Testing connection to STF with #{options}") if $log
    qdr_client = Qpid::Proton::Container.new(OpenStackStfEventTestReceiver.new(self.build_qdr_client_url(options), DEFAULT_TOPIC_NAME))
    qdr_client.run
    return true
  rescue => ex
    $log.info("OpenstackSTFEventMonitor availability check failed with #{ex}.") if $log
    false
  ensure
    qdr_client.close if qdr_client.respond_to? :close
    qdr_client.stop if qdr_client.respond_to? :stop
  end

  def self.plugin_priority
    1
  end

  def self.build_qdr_client_url(options)
    $log.debug("Building STF QDR client connection with #{options.inspect}..") if $log
    protocol = options[:security_protocol].to_s.start_with?('ssl') ? 'amqps' : 'amqp'
    hostname = options[:hostname]
    port     = options[:port] || DEFAULT_AMQP_PORT
    "#{protocol}://#{hostname}:#{port}"
  end

  def initialize(options = {})
    $log.info("Building STF QDR client INIT #{options.inspect}..") if $log
    @options = options
    @ems = options[:ems]
    @config = options.fetch(:stf, {})

    #@collecting_events = false
    @events = []
    @events_mutex = Mutex.new

    @recv_block = ->(event) { puts "ev in recv_block"; @events << event }
    
    @qdr_receiver = Qpid::Proton::Container.new(OpenStackStfEventReceiver.new(self.class.build_qdr_client_url(@options), @config[:topic_name] || DEFAULT_TOPIC_NAME, @recv_block, @events_mutex))
  end

  def start
    return if @qdr_receiver.running > 0
    $log.info("STF QDR client START..") if $log
    @handler = Thread.start { @qdr_receiver.run }
  end

  def stop
    $log.info("STF QDR client STOP..") if $log
    @qdr_receiver&.stop
    @handler&.terminate!
  end

  def each_batch
    $log.info("Building STF QDR client EACHBATCH..") if $log
    @collecting_events = true
    while @collecting_events
      @events_mutex.synchronize do
        $log.info("MIQ(#{self.class.name}) STF Yielding #{@events.size} events to"\
                   " event_catcher: #{@events.map { |e| e }}") if $log

        @events.map! do |raw_event|
          p "unserialize"
          p raw_event
          unserialized_event = unserialize_event(raw_event)
          p "convert"
          converted_event = OpenstackStfEventConverter.new(unserialized_event)
          $log.debug("Processing a new OpenStack STF Event: #{unserialized_event.inspect}") if $log
          openstack_event(nil, converted_event.metadata, converted_event.payload)
          #openstack_event(nil, converted_event, converted_event.fetch(:payload))
        end
          
        yield filter_event_types(@events)
        $log.info("MIQ(#{self.class.name}) Clearing events") if $log && @events.any?
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

  def unserialize_event(raw_event)
    msg = JSON.parse(raw_event)
    event = JSON.parse(msg["request"]["oslo.message"])
    event["payload"] = event["payload"].first
    event
  rescue => ex  # need cover more exceptions than JSON::ParserError
    $log.error("MIQ(#{self.class.name}) Error unserializing STF Event #{ex}") if $log
    {}
  end

  def filter_event_types(events)
    $log.info("Received new OpenStack STF events: (before filtering)") if $log && events.any?
    $log.info(events.inspect) if $log && events.any?
    @event_type_regex ||= Regexp.new(@config[:event_types_regex].to_s)
    events.select { |event| @event_type_regex.match(event.event_type) }
  end
end

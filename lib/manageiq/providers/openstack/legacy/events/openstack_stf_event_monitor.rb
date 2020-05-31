require 'manageiq/providers/openstack/legacy/openstack_event_monitor'
require 'manageiq/providers/openstack/legacy/events/openstack_event'
require 'manageiq/providers/openstack/legacy/events/openstack_stf_event_converter'

class OpenstackStfEventMonitor < OpenstackEventMonitor
  DEFAULT_AMQP_PORT  = 5666
  DEFAULT_TOPIC_NAME = 'anycast/ceilometer/event.sample'.freeze

  def self.qpid_proton_container(*args)
    require 'qpid_proton'
    Qpid::Proton::Container.new(args)
  end

  def self.available?(options = {})
    require 'manageiq/providers/openstack/legacy/events/openstack_stf_event_test_receiver'
    $log.info("Testing connection to STF..") if $log
    $log.debug("With STF options: #{options.inspect}") if $log
    qdr_client = qpid_proton_container(OpenStackStfEventTestReceiver.new(build_qdr_client_url(options), DEFAULT_TOPIC_NAME))
    qdr_client.run
    true
  rescue => ex
    $log.info("OpenstackSTFEventMonitor availability check failed with #{ex}.") if $log
    false
  ensure
    qdr_client.close if qdr_client.respond_to?(:close)
    qdr_client.stop if qdr_client.respond_to?(:stop)
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

    @events = []
    @events_mutex = Mutex.new

    @recv_block = ->(event) { @events << event }

    require 'manageiq/providers/openstack/legacy/events/openstack_stf_event_receiver'
    @qdr_receiver = self.class.qpid_proton_container(OpenStackStfEventReceiver.new(self.class.build_qdr_client_url(@options), @config[:topic_name] || DEFAULT_TOPIC_NAME, @recv_block, @events_mutex))
  end

  def start
    return if @qdr_receiver.running > 0

    $log.info("STF QDR client START..") if $log
    @collecting_events = true
    @handler           = Thread.start { @qdr_receiver.run }
  end

  def stop
    $log.info("STF QDR client STOP..") if $log
    @collecting_events = false
    @qdr_receiver&.stop
    @handler&.terminate
  end

  def each_batch
    while @collecting_events && @qdr_receiver.running > 0
      @events_mutex.synchronize do
        converted_events = @events.map do |raw_event|
          unserialized_event = unserialize_event(raw_event)
          converted_event = OpenstackStfEventConverter.new(unserialized_event)
          $log.debug("Processing a new OpenStack STF Event: #{unserialized_event.inspect}") if $log
          openstack_event(nil, converted_event.metadata, converted_event.payload)
        end

        filtered_events = filter_event_types(converted_events)

        $log.info("MIQ(#{self.class.name}) STF Yielding #{filtered_events.size} events to"\
        " event_catcher: #{filtered_events.map { |e| e }}") if $log

        yield filtered_events

        $log.info("MIQ(#{self.class.name}) Clearing events") if $log && @events.any? && filtered_events.any?
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
    @event_type_regex ||= Regexp.new(@config[:event_types_regex].to_s)
    events.select { |event| @event_type_regex.match(event.payload.fetch("event_type")) }
  end
end

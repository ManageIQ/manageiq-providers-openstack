require 'manageiq/providers/openstack/legacy/openstack_event_monitor'
require 'manageiq/providers/openstack/legacy/events/openstack_event'
require 'manageiq/providers/openstack/legacy/events/openstack_ceilometer_event_converter'
require 'fog/openstack'

class OpenstackCeilometerEventMonitor < OpenstackEventMonitor
  def self.available?(options = {})
    if event_services.keys.include? event_service_settings
      $log.debug "#{_log.prefix} Using events provided by \"#{event_service_settings}\" service, which was set in settings.yml."
      options[:ems].connect(:service => event_services[event_service_settings])
      return true
    end
    begin
      options[:ems].connect(:service => "Event")
      return true
    rescue MiqException::ServiceNotAvailable => ex
      $log.debug("Skipping Openstack Panko events. Availability check failed with #{ex}. Trying Ceilometer.") if $log
      options[:ems].connect(:service => "Metering")
    end
  end

  def self.plugin_priority
    1
  end

  def initialize(options = {})
    @options                              = options
    @ems                                  = options[:ems]
    @config                               = options.fetch(:ceilometer, {})
    @events_service, @provider_connection = initialize_events_service
    @events_class                         = "Fog::#{@events_service}::OpenStack::Event".constantize
  end

  def start
    @since          = nil
    @monitor_events = true
  end

  def stop
    @monitor_events = false
  end

  def provider_connection
    @provider_connection ||= @ems.connect(:service => @events_service)
  end

  def each_batch
    while @monitor_events
      $log.info("Querying OpenStack for events newer than #{latest_event_timestamp}...") if $log
      events = list_events(query_options).sort_by(&:generated)
      @since = events.last.generated unless events.empty?

      amqp_events = filter_unwanted_events(events).map do |event|
        converted_event = OpenstackCeilometerEventConverter.new(event)
        $log.debug("Processing a new OpenStack event: #{event.inspect}") if $log
        openstack_event(nil, converted_event.metadata, converted_event.payload)
      end

      yield amqp_events
    end
  end

  def each
    each_batch do |events|
      events.each { |e| yield e }
    end
  end

  def self.event_service_settings
    Settings[:workers][:worker_base][:event_catcher][:event_catcher_openstack_service]
  rescue StandardError => err
    $log.warn "Settings key :event_catcher_openstack_service is missing, #{err}."
    nil
  end

  def self.event_services
    {"panko" => "Event", "ceilometer" => "Metering"}
  end

  private

  def filter_unwanted_events(events)
    $log.debug("Received a new OpenStack events batch: (before filtering)") if $log && events.any?
    $log.debug(events.inspect) if $log && events.any?
    @event_type_regex ||= Regexp.new(@config[:event_types_regex].to_s)
    events.select { |event| @event_type_regex.match(event.event_type) }
  end

  def query_options
    [{
      'field' => 'start_timestamp',
      'op'    => 'ge',
      'value' => latest_event_timestamp || ''
    }]
  end

  def list_events(query_options)
    provider_connection.list_events(query_options).body.map do |event_hash|
      @events_class.new(event_hash)
    end
  end

  def latest_event_timestamp
    @since ||= @ems.ems_events.maximum(:timestamp)
  end

  def initialize_events_service
    return self.class.event_services[self.class.event_service_settings], @ems.connect(:service => self.class.event_services[self.class.event_service_settings]) if self.class.event_services.keys.include? self.class.event_service_settings
    begin
      return "Event", @ems.connect(:service => "Event")
    rescue MiqException::ServiceNotAvailable => ex
      $log.debug("Panko is not available, trying access events using Ceilometer (#{ex.inspect})") if $log
      return "Metering", @ems.connect(:service => "Metering")
    end
  end
end

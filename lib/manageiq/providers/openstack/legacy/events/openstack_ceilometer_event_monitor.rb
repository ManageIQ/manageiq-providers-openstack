require 'manageiq/providers/openstack/legacy/openstack_event_monitor'
require 'manageiq/providers/openstack/legacy/events/openstack_event'
require 'manageiq/providers/openstack/legacy/events/openstack_ceilometer_event_converter'

class OpenstackCeilometerEventMonitor < OpenstackEventMonitor
  include TimezoneMixin

  def self.available?(options = {})
    return connect_service_from_settings(options[:ems]) if event_services.keys.include? event_service_settings
    begin
      @panko = true
      options[:ems].connect(:service => "Event")
      return true
    rescue MiqException::ServiceNotAvailable => ex
      @panko = false
      $log.debug("Skipping Openstack Panko events. Availability check failed with #{ex}. Trying Ceilometer.") if $log
      options[:ems].connect(:service => "Metering")
    end
  end

  def self.plugin_priority
    1
  end

  def initialize(options = {})
    @options = options
    @ems = options[:ems]
    @config = options.fetch(:ceilometer, {})
  end

  def start
    @since          = nil
    @monitor_events = true
  end

  def stop
    @monitor_events = false
  end

  def provider_connection
    return @provider_connection ||= self.class.connect_service_from_settings(@ems) if self.class.event_services.keys.include? self.class.event_service_settings
    begin
      @panko = true
      @provider_connection ||= @ems.connect(:service => "Event")
    rescue MiqException::ServiceNotAvailable => ex
      @panko = false
      $log.debug("Panko is not available, trying access events using Ceilometer (#{ex.inspect})") if $log
      @provider_connection = @ems.connect(:service => "Metering")
    end
  end

  def event_backread_seconds
    event_backread = Settings.fetch_path(:ems, :ems_openstack, :event_handling, :event_backread_seconds) || 0
    event_backread.seconds
  end

  def each_batch
    while @monitor_events
      $log.info("Querying OpenStack for events newer than #{latest_event_timestamp}...") if $log
      events = list_events(query_options).sort_by(&:generated)

      # Count back a few seconds to catch events that may have arrived in panko
      # out of order. OSP recommends return time in UTC. Skip time conversion when disabled.
      if event_backread_seconds < 1
        @since = events.last.generated unless events.empty?
      else
        with_a_timezone('UTC') do
          last_seen = events.last.generated unless events.empty?
          @since = (Time.zone.parse(last_seen) - event_backread_seconds).iso8601 if last_seen
        end
      end

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

  def self.connect_service_from_settings(ems)
    $log.debug "#{_log.prefix} Using events provided by \"#{event_service_settings}\" service, which was set in settings.yml."
    @panko = (event_service_settings == "panko")
    ems.connect(:service => event_services[event_service_settings])
  end

  def self.event_service_settings
    Settings[:workers][:worker_base][:event_catcher][:event_catcher_openstack_service]
  rescue StandardError => err
    $log.warn "#{_log.prefix} Settings key :event_catcher_openstack_service is missing, #{err}."
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
    options = [{
      'field' => 'start_timestamp',
      'op'    => 'ge',
      'value' => latest_event_timestamp || ''
    }]
    if @panko && tenant_sensitive?
      # all_tenants is not supported by ceilometer
      # and will cause no results to be returned,
      # so only include it if we're querying panko.
      options << {
        'field' => 'all_tenants',
        'value' => 'True'
      }
    end
    options
  end

  def list_events(query_options)
    provider_connection.list_events(query_options).body.map do |event_hash|
      begin
        Fog::Event::OpenStack::Event.new(event_hash)
      rescue NameError
        Fog::Metering::OpenStack::Event.new(event_hash)
      end
    end
  end

  def skip_history?
    Settings.fetch_path(:ems, :ems_openstack, :event_handling, :event_skip_history) || false
  end

  def latest_event_timestamp
    return @since if @since.present?

    @since = @ems.ems_events.maximum(:timestamp) || skip_history? ? @ems.created_on.iso8601 : nil
  end

  def tenant_sensitive?
    # keystone v2 doesn't accept all_tenants flag even in Panko
    @ems.respond_to?(:parent_manager) ? @ems.parent_manager.api_version != 'v2' : @ems.api_version != 'v2'
  end
end

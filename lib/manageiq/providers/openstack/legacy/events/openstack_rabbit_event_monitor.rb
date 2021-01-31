require 'manageiq/providers/openstack/legacy/openstack_event_monitor'
require 'manageiq/providers/openstack/legacy/events/openstack_event'
require 'bunny'

class OpenstackRabbitEventMonitor < OpenstackEventMonitor
  DEFAULT_AMQP_PORT = 5672
  DEFAULT_AMQP_HEARTBEAT = 30
  DEFAULT_AMQP_VHOST = '/'

  # The rabbit event monitor is available if a connection can be established.
  # This ensures that the amqp server is indeed rabbit (and not another amqp
  # implementation).
  def self.available?(options = {})
    hostnames = [options.delete(:hostname), options.delete(:amqp_fallback_hostname1), options.delete(:amqp_fallback_hostname2)]
    hostnames.each do |hostname|
      options[:hostname] = hostname
      return true if test_connection(options)
    end
    false
  end

  def self.plugin_priority
    2
  end

  # Why not inline this?
  # It creates a test mock point for specs
  def self.connect(options = {})
    connection_options = {:host => options[:hostname]}
    connection_options[:port]               = options[:port] || DEFAULT_AMQP_PORT
    connection_options[:heartbeat]          = options[:heartbeat] || DEFAULT_AMQP_HEARTBEAT
    connection_options[:automatic_recovery] = options[:automatic_recovery] if options.key? :automatic_recovery
    connection_options[:recovery_attempts]  = options[:recovery_attempts] if options.key? :recovery_attempts
    connection_options[:vhost]              = options[:vhost] || DEFAULT_AMQP_VHOST

    if options.key? :recover_from_connection_close
      connection_options[:recover_from_connection_close] = options[:recover_from_connection_close]
    end

    if options.key? :username
      connection_options[:username] = options[:username]
      connection_options[:password] = options[:password]
    end
    Bunny.new(connection_options)
  end

  def self.test_connection(options = {})
    connection = nil
    begin
      connection = connect(options)
      connection.start
      return true
    rescue Bunny::AuthenticationFailureError => e
      $log.info("MIQ(#{name}.#{__method__}) Failed testing rabbit amqp connection: #{e.message}")
      $log.error("Credentials Error: Login failed due to a bad username or password.") if $log
    rescue Bunny::TCPConnectionFailedForAllHosts => e
      $log.error("Socket error: #{e.message}") if $log
    rescue => e
      log_prefix = "MIQ(#{name}.#{__method__}) Failed testing rabbit amqp connection for #{options[:hostname]}. "
      $log.info("#{log_prefix} The Openstack AMQP service may be using a different provider."\
                " Enable debug logging to see connection exception.") if $log
      $log.debug("#{log_prefix} Exception: #{e}") if $log
    ensure
      connection.close if connection.respond_to? :close
    end
    false
  end

  def initialize(options = {})
    @options          = options
    @options[:port] ||= DEFAULT_AMQP_PORT
    @client_ip        = @options[:client_ip]
    @ems_id           = options[:ems].try(:id)

    @collecting_events = false
    @events = []
    # protect threaded access to the events array
    @events_array_mutex = Mutex.new
  end

  def start
    connection.start
    initialize_queues
  end

  def stop
    @connection.close if @connection.respond_to? :close
    @collecting_events = false
  end

  def each_batch
    @collecting_events = true
    subscribe_queues
    while @collecting_events
      @events_array_mutex.synchronize do
        $log.debug("MIQ(#{self.class.name}) Yielding #{@events.size} events to"\
                   " event_catcher: #{@events.map { |e| e.payload["event_type"] }}") if $log
        yield @events
        $log.debug("MIQ(#{self.class.name}) Clearing events") if $log
        @events.clear
      end
      sleep 5
    end
  end

  private

  def connection
    @connection ||= OpenstackRabbitEventMonitor.connect(@options)
  end

  def initialize_queues
    remove_legacy_queues
    begin
      try_initialize_queues(false)
    # If the exchange was created in OpenStack as a durable exchange, it must be
    # opened that way here, too. Attempting to open a durable exchange without
    # specifying ":durable => true" will raise a Bunny::PreconditionFailed
    # exception. Catch this and try again with ":durable => true".
    rescue Bunny::PreconditionFailed => e
      begin
        try_initialize_queues(true)
      # If it fails the second time, the problem was something other than being durable.
      # If this happens, raise the original exception.
      rescue Bunny::PreconditionFailed
        raise e
      end
    end
  end

  def try_initialize_queues(durable)
    @channel = connection.create_channel
    @queues = {}
    if @options[:topics]
      @options[:topics].each do |exchange, topic|
        amqp_exchange = @channel.topic(exchange, :durable => durable)
        queue_name = "miq-#{@client_ip}-#{exchange}-#{@ems_id}"
        @queues[exchange] = @channel.queue(queue_name, :auto_delete => true, :exclusive => true)
                                    .bind(amqp_exchange, :routing_key => topic)
      end
    end
  end

  def remove_legacy_queues
    # Rabbit queues used to be created with incorrect initializing arguments (no
    # auto_delete and no exclusive).  The significant problem with leaving these
    # queues around is that they are not deleted when the event monitor
    # disconnects from Rabbit.  And the queues continue to collect messages with
    # no client to drain them.
    channel = connection.create_channel
    @options[:topics].each do |exchange, _topic|
      queue_name = "miq-#{@client_ip}-#{exchange}-#{@ems_id}"
      channel.queue_delete(queue_name) if connection.queue_exists?(queue_name)
    end

    # notifications.* is a poorly named extra-old legacy queue
    queue_name = "notifications.*"
    channel.queue_delete(queue_name) if connection.queue_exists?(queue_name)

    channel.close
  end

  def subscribe_queues
    @queues.each do |exchange, queue|
      queue.subscribe do |delivery_info, metadata, payload|
        begin
          payload = JSON.parse(payload)
          event = openstack_event(delivery_info, metadata, payload)
          @events_array_mutex.synchronize do
            @events << event
            $log.debug("MIQ(#{self.class.name}##{__method__}) Received Rabbit (amqp) event"\
                       " on #{exchange} from #{@options[:hostname]}: #{payload["event_type"]}") if $log
          end
        rescue e
          $log.error("MIQ(#{self.class.name}##{__method__}) Exception receiving Rabbit (amqp)"\
                     " event on #{exchange} from #{@options[:hostname]}: #{e}") if $log
        end
      end
    end
  end
end

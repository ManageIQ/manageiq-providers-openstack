class ManageIQ::Providers::Openstack::CloudManager::MetricsCapture < ManageIQ::Providers::Openstack::BaseMetricsCapture
  CPU_METERS     = ["cpu_util"]
  MEMORY_METERS  = ["memory.usage"]
  DISK_METERS    = ["disk.read.bytes", "disk.write.bytes"]
  NETWORK_METERS = ["network.incoming.bytes", "network.outgoing.bytes"]

  # The list of meters that provide "cumulative" meters instead of "gauge"
  # meters from openstack.  The values from these meters will have to be
  # diffed against the previous value in order to grab a discrete value.
  DIFF_METERS    = DISK_METERS + NETWORK_METERS
  def self.diff_meter?(meters)
    meters = [meters] unless meters.kind_of? Array
    meters.all? { |m| DIFF_METERS.include? m }
  end

  def self.counter_sum_per_second_calculation(stats, intervals)
    total = 0.0
    stats.keys.each do |c|
      total += (intervals[c] > 0) ? stats[c] / intervals[c].to_f : 0
    end
    total / 1024.0
  end

  COUNTER_INFO   = [
    {
      :openstack_counters    => CPU_METERS,
      :calculation           => ->(stat, _) { stat },
      :vim_style_counter_key => "cpu_usage_rate_average"
    },

    {
      :openstack_counters    => MEMORY_METERS,
      :calculation           => ->(stat, _) { stat },
      :vim_style_counter_key => "derived_memory_used"
    },

    {
      :openstack_counters    => DISK_METERS,
      :calculation           => method(:counter_sum_per_second_calculation).to_proc,
      :vim_style_counter_key => "disk_usage_rate_average"
    },

    {
      :openstack_counters    => NETWORK_METERS,
      :calculation           => method(:counter_sum_per_second_calculation).to_proc,
      :vim_style_counter_key => "net_usage_rate_average"
    },
  ]

  COUNTER_NAMES = COUNTER_INFO.collect { |i| i[:openstack_counters] }.flatten.uniq

  VIM_STYLE_COUNTERS = {
    "cpu_usage_rate_average"  => {
      :counter_key           => "cpu_usage_rate_average",
      :instance              => "",
      :capture_interval      => "20",
      :precision             => 1,
      :rollup                => "average",
      :unit_key              => "percent",
      :capture_interval_name => "realtime"
    },

    "derived_memory_used"   => {
      :counter_key           => "derived_memory_used",
      :instance              => "",
      :capture_interval      => "20",
      :precision             => 1,
      :rollup                => "average",
      :unit_key              => "megabytes",
      :capture_interval_name => "realtime"
    },

    "disk_usage_rate_average" => {
      :counter_key           => "disk_usage_rate_average",
      :instance              => "",
      :capture_interval      => "20",
      :precision             => 2,
      :rollup                => "average",
      :unit_key              => "kilobytespersecond",
      :capture_interval_name => "realtime"
    },

    "net_usage_rate_average"  => {
      :counter_key           => "net_usage_rate_average",
      :instance              => "",
      :capture_interval      => "20",
      :precision             => 2,
      :rollup                => "average",
      :unit_key              => "kilobytespersecond",
      :capture_interval_name => "realtime"
    }
  }

  def perf_capture_data(start_time, end_time)
    resource_filter = {"field" => "resource_id", "value" => target.ems_ref}
    metadata_filter = {"field" => "metadata.instance_id", "value" => target.ems_ref}

    perf_capture_data_openstack_base(self.class, start_time, end_time, resource_filter,
                                     metadata_filter)
  end

  def add_gnocchi_meter_counters(counters, resource_filter)
    # With Gnocchi, the network metrics are not associated with the instance's resource id
    # but with the instance's network interface resource id. Here we fetch the counters
    # for the network interface, so that the network metrics can be fetched.
    if target.respond_to?(:network_ports)
      target.network_ports.each do |port|
        # fetch the list of resources and use the original_resource_id and type to find
        # the network interface's resource
        original_resource_id = "#{target.ems_ref}-tap#{port.ems_ref[0..10]}"
        resources = @perf_ems.list_resources('instance_network_interface').body
        resources.each do |r|
          if r["type"].to_s == "instance_network_interface" && r["original_resource_id"].include?(original_resource_id)
            resource_filter = {"field" => "resource_id", "value" => r["id"]}
            counters += list_resource_meters(resource_filter, log_header)
          end
        end
      end
    end
  end
end

class ManageIQ::Providers::Openstack::CloudManager::MetricsCollectorWorker < ::MiqEmsMetricsCollectorWorker
  self.default_queue_name = "openstack"

  def friendly_name
    @friendly_name ||= "C&U Metrics Collector for Openstack"
  end
end

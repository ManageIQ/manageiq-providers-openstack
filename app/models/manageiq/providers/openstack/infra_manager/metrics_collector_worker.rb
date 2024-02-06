class ManageIQ::Providers::Openstack::InfraManager::MetricsCollectorWorker < ::MiqEmsMetricsCollectorWorker
  self.default_queue_name = "openstack_infra"

  def friendly_name
    @friendly_name ||= "C&U Metrics Collector for OpenstackInfra"
  end

  def self.settings_name
    :ems_metrics_collector_worker_openstack_infra
  end
end

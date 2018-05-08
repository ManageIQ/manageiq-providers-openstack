class ManageIQ::Providers::Openstack::InfraManager::RefreshWorker < ::MiqEmsRefreshWorker
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::Openstack::InfraManager
  end

  # overriding queue_name_for_ems so PerEmsWorkerMixin picks up *all* of the
  # Openstack-manager types from here.
  # This way, the refresher for Openstack's InfraManager will refresh *all*
  # of the Openstack inventory across all managers.
  class << self
    def queue_name_for_ems(ems)
      return ems unless ems.kind_of?(ExtManagementSystem)
      combined_managers(ems).collect(&:queue_name).sort
    end

    private

    def combined_managers(ems)
      [ems].concat(ems.child_managers)
    end
  end

  # MiQ complains if this isn't defined
  def queue_name_for_ems(ems)
  end

  def self.settings_name
    :ems_refresh_worker_openstack_infra
  end
end

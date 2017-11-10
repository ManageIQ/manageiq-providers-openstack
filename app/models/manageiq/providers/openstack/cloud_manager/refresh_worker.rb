class ManageIQ::Providers::Openstack::CloudManager::RefreshWorker < ::MiqEmsRefreshWorker
  require_nested :Runner

  # overriding queue_name_for_ems so PerEmsWorkerMixin picks up *all* of the
  # Openstack-manager types from here.
  # This way, the refresher for Openstack's CloudManager will refresh *all*
  # of the Openstack inventory across all managers.
  def self.queue_name_for_ems(ems)
    if ems.kind_of?(ExtManagementSystem)
      ["ems_#{ems.id}"] + ems.child_managers.collect { |manager| "ems_#{manager.id}" }
    else
      super
    end
  end

  # MiQ complains if this isn't defined
  def queue_name_for_ems(ems)
  end

  def self.ems_class
    ManageIQ::Providers::Openstack::CloudManager
  end
end

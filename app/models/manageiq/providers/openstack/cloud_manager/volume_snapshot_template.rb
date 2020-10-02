class ManageIQ::Providers::Openstack::CloudManager::VolumeSnapshotTemplate < ManageIQ::Providers::Openstack::CloudManager::BaseTemplate
  # VolumeSnapshotTemplates are proxies to allow provisioning instances from volumes
  # without having to refactor the entire provisioning workflow to support types
  # other than VmOrTemplate subtypes. VolumeSnapshotTemplates are created 1-to-1 during
  # inventory refresh for each eligible snapshot.

  belongs_to :cloud_tenant

  def volume_snapshot_template?
    true
  end

  def self.display_name(number = 1)
    n_('Volume Snapshot Template (Openstack)', 'Volume Snapshot Templates (Openstack)', number)
  end
end

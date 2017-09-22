class ManageIQ::Providers::Openstack::CloudManager::VolumeTemplate < ManageIQ::Providers::CloudManager::Template
  # VolumeTemplates are proxies to allow provisioning instances from volumes
  # without having to refactor the entire provisioning workflow to support types
  # other than VmOrTemplate subtypes. VolumeTemplates are created 1-to-1 during
  # inventory refresh for each eligible bootable volume.

  belongs_to :cloud_tenant

  def volume_template?
    true
  end
end

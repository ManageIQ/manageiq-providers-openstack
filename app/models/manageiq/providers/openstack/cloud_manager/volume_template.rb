class ManageIQ::Providers::Openstack::CloudManager::VolumeTemplate < ManageIQ::Providers::Openstack::CloudManager::BaseTemplate
  # VolumeTemplates are proxies to allow provisioning instances from volumes
  # without having to refactor the entire provisioning workflow to support types
  # other than VmOrTemplate subtypes. VolumeTemplates are created 1-to-1 during
  # inventory refresh for each eligible bootable volume.

  belongs_to :cloud_tenant

  def volume_template?
    true
  end

  def self.display_name(number = 1)
    n_('Volume Template (Openstack)', 'Volume Templates (Openstack)', number)
  end
end

module ManageIQ::Providers::Openstack::CloudManager::Vm::Operations
  extend ActiveSupport::Concern

  include Configuration
  include Guest
  include Power
  include Relocation
  include Snapshot

  included do
    supports(:terminate) { unsupported_reason(:control) }
  end

  def raw_destroy
    raise "VM has no #{ui_lookup(:table => "ext_management_systems")}, unable to destroy VM" unless ext_management_system
    with_notification(:vm_destroy,
                      :options => {
                        :subject => self,
                      }) do
      with_provider_object(&:destroy)
    end
    self.update!(:raw_power_state => "DELETED")
  end
end

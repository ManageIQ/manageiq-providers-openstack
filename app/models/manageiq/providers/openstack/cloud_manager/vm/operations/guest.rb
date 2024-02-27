module ManageIQ::Providers::Openstack::CloudManager::Vm::Operations::Guest
  extend ActiveSupport::Concern

  included do
    supports :reboot_guest do
      if current_state != "on"
        _("The VM is not powered on")
      else
        unsupported_reason(:control)
      end
    end

    supports :reset do
      if current_state != "on"
        _("The VM is not powered on")
      else
        unsupported_reason(:control)
      end
    end
  end

  def raw_reboot_guest
    with_provider_object(&:reboot)
    # Temporarily update state for quick UI response until refresh comes along
    self.update!(:raw_power_state => "REBOOT")
  end

  def raw_reset
    with_provider_object { |instance| instance.reboot("HARD") }
    # Temporarily update state for quick UI response until refresh comes along
    self.update!(:raw_power_state => "HARD_REBOOT")
  end
end

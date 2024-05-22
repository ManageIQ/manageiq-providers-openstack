class ManageIQ::Providers::Openstack::CloudManager::BaseTemplate < ManageIQ::Providers::CloudManager::Template
  supports :provisioning do
    if ext_management_system
      ext_management_system.unsupported_reason(:provisioning)
    else
      _('not connected to ems')
    end
  end
end

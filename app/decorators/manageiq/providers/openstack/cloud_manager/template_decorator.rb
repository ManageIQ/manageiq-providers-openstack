class ManageIQ::Providers::Openstack::CloudManager::TemplateDecorator < MiqTemplateDecorator
  def provisioning_volume_size_tooltip
    _("Default value is 1")
  end
end

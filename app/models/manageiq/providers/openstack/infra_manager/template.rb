class ManageIQ::Providers::Openstack::InfraManager::Template < ManageIQ::Providers::InfraManager::Template
  belongs_to :cloud_tenant

  supports(:smartstate_analysis) { unsupported_reason(:active) }
  supports_not :clone

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.images.get(ems_ref)
  end

  def has_active_proxy?
    true
  end

  def has_proxy?
    true
  end
end

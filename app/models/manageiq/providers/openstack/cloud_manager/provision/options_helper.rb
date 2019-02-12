module ManageIQ::Providers::Openstack::CloudManager::Provision::OptionsHelper
  def cloud_tenant
    @cloud_tenant ||= CloudTenant.find_by(:id => get_option(:cloud_tenant))
  end

  def network_port
    @network_port ||= NetworkPort.find_by(:id => get_option(:network_port))
  end

  def cloud_network_selection_method
    @cloud_network_selection_method ||= get_option(:cloud_network_selection_method)
  end
end

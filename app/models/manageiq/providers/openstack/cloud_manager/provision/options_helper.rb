module ManageIQ::Providers::Openstack::CloudManager::Provision::OptionsHelper
  def cloud_tenant
    @cloud_tenant ||= CloudTenant.find_by(:id => get_option(:cloud_tenant))
  end
end

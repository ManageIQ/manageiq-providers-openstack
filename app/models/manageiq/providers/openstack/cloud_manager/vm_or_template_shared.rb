module ManageIQ::Providers::Openstack::CloudManager::VmOrTemplateShared
  extend ActiveSupport::Concern
  include_concern 'Scanning'
end

class ManageIQ::Providers::Openstack::CloudManager::Provision < ::MiqProvisionCloud
  include ManageIQ::Providers::Openstack::HelperMethods
  include Cloning
  include Configuration
  include VolumeAttachment
  include OptionsHelper
end

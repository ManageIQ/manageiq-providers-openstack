class ManageIQ::Providers::Openstack::StorageManager::SwiftManager < ManageIQ::Providers::StorageManager::SwiftManager
  include ManageIQ::Providers::Openstack::HelperMethods

  delegate :authentication_check,
           :authentication_status,
           :authentication_status_ok,
           :authentications,
           :authentication_for_summary,
           :zone,
           :swift_service,
           :connect,
           :verify_credentials,
           :with_provider_connection,
           :address,
           :ip_address,
           :hostname,
           :default_endpoint,
           :endpoints,
           :to        => :parent_manager,
           :allow_nil => true

  supports :cloud_object_store_container_create

  supports :swift_service do
    if parent_manager
      unsupported_reason_add(:swift_service, parent_manager.unsupported_reason(:swift_service)) unless
          parent_manager.supports_swift_service?
    else
      unsupported_reason_add(:swift_service, _('no parent_manager to ems'))
    end
  end

  def self.hostname_required?
    false
  end

  def self.ems_type
    @ems_type ||= "swift".freeze
  end

  def self.description
    @description ||= "Swift ".freeze
  end

  def description
    @description ||= "Swift ".freeze
  end

  def name
    "#{parent_manager.try(:name)} Swift Manager"
  end
end

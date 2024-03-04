class ManageIQ::Providers::Openstack::StorageManager::SwiftManager < ManageIQ::Providers::StorageManager
  include ManageIQ::Providers::StorageManager::ObjectMixin

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

  supports :swift_service do
    if parent_manager
      parent_manager.unsupported_reason(:swift_service)
    else
      _('no parent_manager to ems')
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

  def allow_targeted_refresh?
    false
  end

  def self.display_name(number = 1)
    n_('Storage Manager (Swift)', 'Storage Managers (Swift)', number)
  end
end

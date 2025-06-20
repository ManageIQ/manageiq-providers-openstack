class ManageIQ::Providers::Openstack::StorageManager::CinderManager < ManageIQ::Providers::StorageManager
  include ManageIQ::Providers::StorageManager::BlockMixin
  include ManageIQ::Providers::Openstack::ManagerMixin

  supports :cinder_volume_types
  supports :volume_multiattachment
  supports :volume_resizing
  supports :volume_availability_zones
  supports :cloud_volume
  supports :cloud_volume_create

  supports :events do
    if parent_manager
      parent_manager.unsupported_reason(:events)
    else
      _('no parent_manager to ems')
    end
  end

  # Auth and endpoints delegations, editing of this type of manager must be disabled
  delegate :authentication_check,
           :authentication_status,
           :authentication_status_ok?,
           :authentications,
           :authentication_for_summary,
           :zone,
           :openstack_handle,
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

  virtual_has_many :cloud_tenants, :through => :parent_manager
  virtual_has_many :volume_availability_zones, :through => :parent_manager, :class_name => "AvailabilityZone"

  class << self
    delegate :refresh_ems, :to => ManageIQ::Providers::Openstack::CloudManager
  end

  def self.hostname_required?
    false
  end

  def self.ems_type
    @ems_type ||= "cinder".freeze
  end

  def self.description
    @description ||= "Cinder ".freeze
  end

  def description
    @description ||= "Cinder ".freeze
  end

  def name
    "#{parent_manager.try(:name)} Cinder Manager"
  end

  def supported_auth_types
    %w(default amqp)
  end

  def self.event_monitor_class
    ManageIQ::Providers::Openstack::StorageManager::CinderManager::EventCatcher
  end

  def allow_targeted_refresh?
    true
  end

  def stop_event_monitor_queue_on_change
    if !self.new_record? && parent_manager && (authentications.detect{ |x| x.previous_changes.present? } ||
                                                    endpoints.detect{ |x| x.previous_changes.present? })
      _log.info("EMS: [#{name}], Credentials or endpoints have changed, stopping Event Monitor. It will be restarted by the WorkerMonitor.")
      stop_event_monitor_queue
    end
  end

  def self.display_name(number = 1)
    n_('Cinder Block Storage Manager (OpenStack)', 'Cinder Block Storage Managers (OpenStack)', number)
  end
end

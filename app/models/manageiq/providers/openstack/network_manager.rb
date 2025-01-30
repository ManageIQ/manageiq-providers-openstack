class ManageIQ::Providers::Openstack::NetworkManager < ManageIQ::Providers::NetworkManager
  include ManageIQ::Providers::Openstack::ManagerMixin
  include SupportsFeatureMixin

  supports :create_network_router
  supports :cloud_subnet_create

  supports :events do
    if parent_manager
      parent_manager.unsupported_reason(:events)
    else
      _('no parent_manager to ems')
    end
  end

  has_many :public_networks,  :foreign_key => :ems_id, :dependent => :destroy,
           :class_name => "ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Public"
  has_many :private_networks, :foreign_key => :ems_id, :dependent => :destroy,
           :class_name => "ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Private"

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

  class << self
    delegate :refresh_ems, :to => ManageIQ::Providers::Openstack::CloudManager
  end

  def self.hostname_required?
    false
  end

  def self.ems_type
    @ems_type ||= "openstack_network".freeze
  end

  def self.description
    @description ||= "OpenStack Network".freeze
  end

  def supported_auth_types
    %w(default amqp)
  end

  def allow_targeted_refresh?
    true
  end

  def self.event_monitor_class
    ManageIQ::Providers::Openstack::NetworkManager::EventCatcher
  end

  def create_cloud_network(options)
    CloudNetwork.raw_create_cloud_network(self, options)
  end

  def create_cloud_network_queue(userid, options = {})
    task_opts = {
      :action => "creating Cloud Network for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'create_cloud_network',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => my_zone,
      :args        => [options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def create_cloud_subnet(options)
    CloudSubnet.raw_create_cloud_subnet(self, options)
  end

  def create_network_router(options)
    NetworkRouter.raw_create_network_router(self, options)
  end

  def create_network_router_queue(userid, options = {})
    task_opts = {
      :action => "creating Network Router for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'create_network_router',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => my_zone,
      :args        => [options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def create_floating_ip(options)
    FloatingIp.raw_create_floating_ip(self, options)
  end

  def create_floating_ip_queue(userid, options = {})
    task_opts = {
      :action => "creating Floating IP for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'create_floating_ip',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => my_zone,
      :args        => [options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def create_security_group(options)
    SecurityGroup.raw_create_security_group(self, options)
  end

  def create_security_group_queue(userid, options = {})
    task_opts = {
      :action => "creating Security Group for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'create_security_group',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => my_zone,
      :args        => [options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.display_name(number = 1)
    n_('Network Provider (OpenStack)', 'Network Providers (OpenStack)', number)
  end
end

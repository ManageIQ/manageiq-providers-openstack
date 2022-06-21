module ManageIQ::Providers::Openstack::EventCatcherMixin
  extend ActiveSupport::Concern

  def self.all_valid_ems_in_zone
    super.select { |ems| ems.supports?(:events) }
  end
end

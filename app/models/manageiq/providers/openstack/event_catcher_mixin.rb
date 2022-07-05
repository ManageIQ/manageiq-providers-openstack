module ManageIQ::Providers::Openstack::EventCatcherMixin
  extend ActiveSupport::Concern

  def after_initialize
    super

    do_exit("EMS ID [#{@cfg[:ems_id]}] event monitor unavailable.", 1) unless ems.event_monitor_available?
  end

  class_methods do
    def all_valid_ems_in_zone
      super.select { |ems| ems.supports?(:events) }
    end
  end
end

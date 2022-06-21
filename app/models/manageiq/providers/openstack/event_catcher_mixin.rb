module ManageIQ::Providers::Openstack::EventCatcherMixin
  extend ActiveSupport::Concern

  class_methods do
    def all_valid_ems_in_zone
      require 'manageiq/providers/openstack/legacy/openstack_event_monitor'
      super.select do |ems|
        ems.event_monitor_available?.tap do |available|
          _log.info("Event Monitor unavailable for #{ems.name}.  Check log history for more details.") unless available
        end
      end
    end
  end
end

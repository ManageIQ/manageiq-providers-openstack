class ManageIQ::Providers::Openstack::NetworkManager::EventTargetParser
  attr_reader :ems_event

  # @param ems_event [EmsEvent] EmsEvent object to be parsed to derive an object to be refreshed
  def initialize(ems_event)
    @ems_event = ems_event
  end

  # Parses all targets present in the EmsEvent given in the initializer
  # @return [Array] Array of InventoryRefresh::Target objects
  def parse
    parse_ems_event_targets(ems_event)
  end

  private

  # Parses list of InventoryRefresh::Target(s) out of the given EmsEvent
  #
  # @param ems_event [EmsEvent] EmsEvent object
  # @return [Array] Array of InventoryRefresh::Target objects
  def parse_ems_event_targets(ems_event)
    target_collection = InventoryRefresh::TargetCollection.new(:manager => ems_event.ext_management_system.parent_manager, :event => ems_event)

    # there's almost always a tenant id regardless of event type
    collect_identity_tenant_references!(target_collection)

    target_type = case resource_type
                  when "floatingip"
                    :floating_ips
                  when "router"
                    :network_routers
                  when "port"
                    :network_ports
                  when "network"
                    :cloud_networks
                  when "subnet"
                    :cloud_subnets
                  when "security_group"
                    :security_groups
                  when "security_group_rule"
                    :firewall_rules
                  end

    if resource_id
      add_target(target_collection, target_type, resource_id)
    elsif target_type == :security_groups
      # Notifications from Panko about new security groups don't include
      # the ID of the security group, so we can't trigger a targeted refresh.
      # Add a dummy reference so that the collector will know that a security
      # group was updated, and that it should refresh the whole security group
      # inventory as a workaround. The same for security_group_rules.
      add_target(target_collection, :security_groups, nil)
    elsif target_type == :firewall_rules
      add_target(target_collection, :firewall_rules, nil)
    end

    target_collection.targets
  end

  def collect_identity_tenant_references!(target_collection)
    tenant_id = event_payload['tenant_id'] || 
                event_payload['project_id'] || 
                event_payload.dig(resource_type, 'tenant_id') ||
                event_payload.dig(resource_type, 'project_id') ||
                event_payload.dig('initiator', 'project_id')
    
    add_target(target_collection, :cloud_tenants, tenant_id) if tenant_id
  end

  def parsed_targets(target_collection = {})
    target_collection.select { |_target_class, references| references[:manager_ref].present? }
  end

  def add_target(target_collection, association, ref)
    target_collection.add_target(:association => association, :manager_ref => {:ems_ref => ref})
  end

  def event_payload
    @event_payload ||= ManageIQ::Providers::Openstack::EventParserCommon.message_content(ems_event).fetch('payload', {})
  end

  def resource_type
    @resource_type ||= ems_event.event_type.split(".").first
  end

  def resource_id
    @resource_id ||= event_payload.dig(resource_type, "id") || event_payload["resource_id"]
  end
end
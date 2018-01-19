class ManageIQ::Providers::Openstack::StorageManager::CinderManager::EventTargetParser
  attr_reader :ems_event

  # @param ems_event [EmsEvent] EmsEvent object to be parsed to derive an object to be refreshed
  def initialize(ems_event)
    @ems_event = ems_event
  end

  # Parses all targets present in the EmsEvent givin in the initializer
  # @return [Array] Array of ManagerRefresh::Target objects
  def parse
    parse_ems_event_targets(ems_event)
  end

  private

  # Parses list of ManagerRefresh::Target(s) out of the given EmsEvent
  #
  # @param ems_event [EmsEvent] EmsEvent object
  # @return [Array] Array of ManagerRefresh::Target objects
  def parse_ems_event_targets(ems_event)
    target_collection = ManagerRefresh::TargetCollection.new(:manager => ems_event.ext_management_system.parent_manager, :event => ems_event)

    # there's almost always a tenant id regardless of event type
    collect_identity_tenant_references!(target_collection, ems_event)

    if ems_event.event_type.start_with?("volume.")
      collect_volume_references!(target_collection, ems_event)
    elsif ems_event.event_type.start_with?("snapshot.")
      collect_snapshot_references!(target_collection, ems_event)
    end

    target_collection.targets
  end

  def collect_volume_references!(target_collection, ems_event)
    resource_id = ems_event.full_data.fetch_path(:content, 'payload', 'volume_id') || ems_event.full_data.fetch_path(:content, 'payload', 'resource_id')
    add_target(target_collection, :cloud_volumes, resource_id) if resource_id
  end

  def collect_snapshot_references!(target_collection, ems_event)
    resource_id = ems_event.full_data.fetch_path(:content, 'payload', 'snapshot_id') || ems_event.full_data.fetch_path(:content, 'payload', 'resource_id')
    add_target(target_collection, :cloud_volume_snapshots, resource_id) if resource_id
    volume_id = ems_event.full_data.fetch_path(:content, 'payload', 'volume_id')
    add_target(target_collection, :cloud_volumes, volume_id) if volume_id
  end

  def collect_identity_tenant_references!(target_collection, ems_event)
    tenant_id = ems_event.full_data.fetch_path(:content, 'payload', 'tenant_id') || ems_event.full_data.fetch_path(:content, 'payload', 'project_id') || ems_event.full_data.fetch_path(:content, 'payload', 'initiator', 'project_id')
    add_target(target_collection, :cloud_tenants, tenant_id) if tenant_id
  end

  def parsed_targets(target_collection = {})
    target_collection.select { |_target_class, references| references[:manager_ref].present? }
  end

  def add_target(target_collection, association, ref)
    target_collection.add_target(:association => association, :manager_ref => {:ems_ref => ref})
  end
end

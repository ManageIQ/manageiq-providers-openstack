class ManageIQ::Providers::Openstack::StorageManager::CinderManager::EventTargetParser
  attr_reader :ems_event

  # @param ems_event [EmsEvent] EmsEvent object to be parsed to derive an object to be refreshed
  def initialize(ems_event)
    @ems_event = ems_event
  end

  # Parses all targets present in the EmsEvent givin in the initializer
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

    if ems_event.event_type.start_with?("volume.")
      collect_volume_references!(target_collection)
    elsif ems_event.event_type.start_with?("snapshot.")
      collect_snapshot_references!(target_collection)
    elsif ems_event.event_type.start_with?("backup.")
      collect_backup_references!(target_collection)
    end

    target_collection.targets
  end

  def collect_volume_references!(target_collection)
    tenant_id = event_payload['project_id']
    resource_id = event_payload['resource_id']
    add_target(target_collection, :cloud_volumes, resource_id, :tenant_id => tenant_id) if resource_id
    # Bootable Volume can be modelled also as VolumeTemplate for new VM provisioning based on the Bootable Volume
    add_target(target_collection, :volume_templates, resource_id, :tenant_id => tenant_id) if resource_id
  end

  def collect_snapshot_references!(target_collection)
    tenant_id = event_payload['project_id']
    resource_id = event_payload['resource_id']
    add_target(target_collection, :cloud_volume_snapshots, resource_id, :tenant_id => tenant_id) if resource_id
    volume_id = event_payload['volume_id']
    add_target(target_collection, :cloud_volumes, volume_id, :tenant_id => tenant_id) if volume_id
  end

  def collect_backup_references!(target_collection)
    # backup notifications from panko don't include IDs, so we can't target
    # a single backup. Add a dummy backup target which will allow us to collect
    # all backups as a workaround.
    add_target(target_collection, :cloud_volume_backups, nil)
  end

  def parsed_targets(target_collection = {})
    target_collection.select { |_target_class, references| references[:manager_ref].present? }
  end

  def add_target(target_collection, association, ref, options = {})
    target_collection.add_target(:association => association, :manager_ref => {:ems_ref => ref}, :options => options)
  end

  def event_payload
    @event_payload ||= ManageIQ::Providers::Openstack::EventParserCommon.message_content(ems_event).fetch('payload', {})
  end
end

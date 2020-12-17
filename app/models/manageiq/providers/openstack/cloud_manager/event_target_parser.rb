class ManageIQ::Providers::Openstack::CloudManager::EventTargetParser
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
    target_collection = InventoryRefresh::TargetCollection.new(:manager => ems_event.ext_management_system, :event => ems_event)

    # there's almost always a tenant id regardless of event type
    collect_identity_tenant_references!(target_collection)

    if ems_event.event_type.start_with?("compute.instance")
      collect_compute_instance_references!(target_collection)
    elsif ems_event.event_type.start_with?("orchestration.stack")
      collect_orchestration_stack_references!(target_collection)
    elsif ems_event.event_type.start_with?("image.")
      collect_image_references!(target_collection)
    elsif ems_event.event_type.start_with?("aggregate.")
      collect_host_aggregate_references!(target_collection)
    elsif ems_event.event_type.start_with?("keypair")
      collect_key_pair_references!(target_collection)
    end

    target_collection.targets
  end

  def parsed_targets(target_collection = {})
    target_collection.select { |_target_class, references| references[:manager_ref].present? }
  end

  def add_target(target_collection, association, ref)
    target_collection.add_target(:association => association, :manager_ref => {:ems_ref => ref})
  end

  def collect_compute_instance_references!(target_collection)
    instance_id = event_payload['instance_id']
    add_target(target_collection, :vms, instance_id) if instance_id
  end

  def collect_image_references!(target_collection)
    resource_id = event_payload['resource_id'] || event_payload['id']
    add_target(target_collection, :images, resource_id) if resource_id # Works for Create and Update action
    add_target(target_collection, :miq_templates, resource_id) if resource_id # Existing association name needed for Delete action
  end

  def collect_identity_tenant_references!(target_collection)
    tenant_id = event_payload['tenant_id'] || event_payload['project_id'] || event_payload.fetch_path('initiator', 'project_id')
    add_target(target_collection, :cloud_tenants, tenant_id) if tenant_id
  end

  def collect_orchestration_stack_references!(target_collection)
    stack_id = event_payload['stack_id'] || event_payload['resource_id']
    tenant_id = event_payload['tenant_id']
    target_collection.add_target(:association => :orchestration_stacks, :manager_ref => {:ems_ref => stack_id}, :options => {:tenant_id => tenant_id})
  end

  def collect_host_aggregate_references!(target_collection)
    # aggregate events from ceilometer don't have an id field for the aggregate,
    # but they do have a "service" field in the form of "aggregate.<id>"
    aggregate_id = event_payload['service']
    aggregate_id&.sub!('aggregate.', '')
    add_target(target_collection, :host_aggregates, aggregate_id) if aggregate_id
  end

  def collect_key_pair_references!(target_collection)
    add_target(target_collection, :key_pairs, nil)
  end

  def event_payload
    @event_payload ||= ManageIQ::Providers::Openstack::EventParserCommon.message_content(ems_event).fetch('payload', {})
  end
end

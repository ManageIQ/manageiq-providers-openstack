module ManageIQ::Providers::Openstack::Inventory::Persister::Definitions::StorageCollections
  extend ActiveSupport::Concern

  def initialize_storage_inventory_collections
    %i(cloud_volumes
       cloud_volume_snapshots
       cloud_volume_types
       ).each do |name|

      add_collection(storage, name) do |builder|
        builder.add_properties(:model_class => "#{cinder_manager.class}::#{name.to_s.classify}".constantize)
        builder.add_properties(:parent => manager.cinder_manager) if targeted?
        builder.add_default_values(:ems_id => cinder_manager.id)
      end
    end
    add_cloud_volume_backups
  end

  def add_cloud_volume_backups(extra_properties = {})
    add_collection(storage, :cloud_volume_backups, extra_properties) do |builder|
      builder.add_properties(:model_class => "#{cinder_manager.class}::CloudVolumeBackup".constantize)
      builder.add_properties(:parent => manager.cinder_manager) if targeted?
      builder.add_default_values(:ems_id => cinder_manager.id)

      # targeted refresh workaround-- always refresh the whole backup collection
      # regardless of whether this is a TargetCollection or not
      # because OpenStack doesn't give us UUIDs of changed volume_backups,
      # we just get an event that one of them changed
      if references(:cloud_volume_backups).present?
        builder.add_properties(:targeted => false)
      end
    end
  end

  def add_cinder_collection(collection_name, extra_properties = {}, settings = {}, &block)
    settings[:parent] ||= cinder_manager
    add_collection(storage, collection_name, extra_properties, settings, &block)
  end
end

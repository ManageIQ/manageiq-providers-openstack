module ManageIQ::Providers::Openstack::Inventory::Persister::Definitions::StorageCollections
  extend ActiveSupport::Concern

  def initialize_cinder_inventory_collections
    add_cinder_collection(:cloud_volumes) do |builder|
      builder.add_properties(:model_class => cinder_manager.class::CloudVolume)
    end
    add_cinder_collection(:cloud_volume_snapshots) do |builder|
      builder.add_properties(:model_class => cinder_manager.class::CloudVolumeSnapshot)
    end
    add_cinder_collection(:cloud_volume_types) do |builder|
      builder.add_properties(:model_class => cinder_manager.class::CloudVolumeType)
    end
    add_cinder_collection(:cloud_volume_backups) do |builder|
      builder.add_properties(:model_class => cinder_manager.class::CloudVolumeBackup)
      # targeted refresh workaround-- always refresh the whole backup collection
      # regardless of whether this is a TargetCollection or not
      # because OpenStack doesn't give us UUIDs of changed volume_backups,
      # we just get an event that one of them changed
      builder.add_properties(:targeted => false) if references(:cloud_volume_backups).present?
    end
  end

  def initialize_swift_inventory_collections
    add_swift_collection(:cloud_object_store_objects) do |builder|
      builder.add_properties(:model_class => swift_manager.class::CloudObjectStoreObject)
    end
    add_swift_collection(:cloud_object_store_containers) do |builder|
      builder.add_properties(:model_class => swift_manager.class::CloudObjectStoreContainer)
    end
    add_cloud_collection(:cloud_tenants, {}, {:without_sti => true}) do |builder|
      builder.add_properties(:strategy => :local_db_cache_all, :complete => false)
    end
  end

  def add_cinder_collection(collection_name, extra_properties = {}, settings = {}, &block)
    settings[:parent] ||= cinder_manager
    add_collection(storage, collection_name, extra_properties, settings, &block)
  end

  def add_swift_collection(collection_name, extra_properties = {}, settings = {}, &block)
    settings[:parent] ||= swift_manager
    add_collection(storage, collection_name, extra_properties, settings, &block)
  end
end

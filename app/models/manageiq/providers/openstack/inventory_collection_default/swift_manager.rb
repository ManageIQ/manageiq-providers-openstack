class ManageIQ::Providers::Openstack::InventoryCollectionDefault::SwiftManager < ManagerRefresh::InventoryCollectionDefault::StorageManager
  class << self
    def cloud_object_store_containers(extra_attributes = {})
      attributes = {
        :model_class                 => ::CloudObjectStoreContainer,
        :inventory_object_attributes => [
          :key,
          :object_count,
          :bytes,
          :cloud_tenant
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def cloud_object_store_objects(extra_attributes = {})
      attributes = {
        :model_class                 => ::CloudObjectStoreObject,
        :inventory_object_attributes => [
          :etag,
          :last_modified,
          :content_length,
          :key,
          :content_type,
          :cloud_object_store_container,
          :cloud_tenant
        ]
      }

      super(attributes.merge!(extra_attributes))
    end
  end
end

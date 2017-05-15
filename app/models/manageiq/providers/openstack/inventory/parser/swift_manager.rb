class ManageIQ::Providers::Openstack::Inventory::Parser::SwiftManager < ManagerRefresh::Inventory::Parser
  def parse
    containers
  end

  def containers
    collector.object_store_containers.each do |c|
      container = persister.cloud_object_store_containers.find_or_build("#{c.project.id}/#{c.key}")
      container.key = c.key
      container.object_count = c.count
      container.bytes = c.bytes
      container.cloud_tenant = persister.cloud_tenants.lazy_find(c.project.id)

      collector.object_store_objects(c).each do |o|
        object = persister.cloud_object_store_objects.find_or_build(o.key)
        object.etag = o.etag
        object.last_modified = o.last_modified
        object.content_length = o.content_length
        object.key = o.key
        object.content_type = o.content_type
        object.cloud_object_store_container = container
        object.cloud_tenant = persister.cloud_tenants.lazy_find(c.project.id)
      end
    end
  end
end

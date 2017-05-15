class ManageIQ::Providers::Openstack::Inventory::Collector::SwiftManager < ManagerRefresh::Inventory::Collector
  include ManageIQ::Providers::Openstack::RefreshParserCommon::HelperMethods
  include Vmdb::Logging

  def swift_service
    @os_handle ||= manager.parent_manager.openstack_handle
    @swift_service ||= manager.parent_manager.swift_service
  end

  def object_store_containers
    @object_store_containers ||= swift_service.handled_list(:directories)
  end

  def object_store_objects(container)
    safe_list { container.files }
  end
end

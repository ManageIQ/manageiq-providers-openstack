class ManageIQ::Providers::Openstack::Inventory::Collector::InfraManager < ManageIQ::Providers::Openstack::Inventory::Collector
  include ManageIQ::Providers::Openstack::Inventory::Collector::HelperMethods

  def baremetal_service
    @baremetal_service ||= manager.openstack_handle.detect_baremetal_service
  end

  def storage_service
    @storage_service ||= manager.openstack_handle.detect_storage_service
  end

  def introspection_service
    @introspection_service ||= manager.openstack_handle.detect_introspection_service
  end

  def images
    return [] unless image_service
    return @images if @images.any?

    @images = uniques(image_service.handled_list(:images))
  end

  def servers
    return [] unless compute_service
    return @servers if @servers.any?

    @servers = uniques(compute_service.handled_list(:servers))
  end

  def hosts
    return [] unless baremetal_service
    return @hosts if @hosts.any?

    @hosts = uniques(baremetal_service.handled_list(:nodes))
  end
end

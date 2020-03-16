class ManageIQ::Providers::Openstack::Inventory::Collector::InfraManager < ManageIQ::Providers::Openstack::Inventory::Collector
  include ManageIQ::Providers::Openstack::Inventory::Collector::HelperMethods

  def images
    return [] unless image_service
    return @images if @images.any?

    @images = uniques(image_service.handled_list(:images))
  end
end

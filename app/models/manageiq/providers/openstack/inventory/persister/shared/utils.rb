module ManageIQ::Providers::Openstack::Inventory::Persister::Shared::Utils
  extend ActiveSupport::Concern

  protected

  # Shortcut for better code readability
  def add_collection_with_ems_param(builder_class, collection_name, extra_properties = {}, settings = {})
    add_collection(builder_class, collection_name, extra_properties, settings) do |builder|
      ems_builder_param(builder)

      yield builder if block_given?
    end
  end

  def ems_builder_param(builder)
    builder.add_builder_params(:ext_management_system => manager)
  end
end

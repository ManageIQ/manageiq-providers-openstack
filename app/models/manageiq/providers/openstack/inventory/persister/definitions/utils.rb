module ManageIQ::Providers::Openstack::Inventory::Persister::Definitions::Utils
  extend ActiveSupport::Concern

  protected

  # Shortcut for better code readability
  def add_collection_with_ems_param(builder_class, collection_name, extra_properties = {}, settings = {})
    add_collection(builder_class, collection_name, extra_properties, settings) do |builder|
      ems_default_value(builder)

      yield builder if block_given?
    end
  end

  def ems_default_value(builder)
    builder.add_default_values(:ems_id => manager.id)
  end

  def network_ems_default_value(builder)
    ems = targeted? ? manager.network_manager : manager
    builder.add_default_values(:ems_id => ems.id)
  end
end

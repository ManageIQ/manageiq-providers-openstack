# These methods are available for dialog field validation, do not erase.
module ManageIQ::Providers::Openstack::CloudManager::ProvisionWorkflow::DialogFieldValidation
  def validate_cloud_network(field, values, dlg, fld, value)
    return nil if allowed_cloud_networks.length <= 1
    return nil unless get_value(values[:cloud_network_selection_method]) == 'network'
    validate_placement(field, values, dlg, fld, value)
  end

  def validate_network_port(field, values, dlg, fld, value)
    return nil unless get_value(values[:cloud_network_selection_method]) == 'port'
    validate_placement(field, values, dlg, fld, value)
  end
end

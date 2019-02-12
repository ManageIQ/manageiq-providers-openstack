module ManageIQ::Providers::Openstack::CloudManager::Provision::Configuration
  def associate_floating_ip(ip_address)
    # TODO(lsmola) this should be moved to FloatingIp model
    destination.with_provider_object do |instance|
      instance.associate_address(ip_address.address)
    end
  end

  def configure_network_adapters
    @nics ||= begin
      networks = Array(options[:networks])

      # Set the first nic to whatever was selected in the dialog if not set by automate
      if (cloud_network_selection_method == "network" && cloud_network) || (cloud_network_selection_method == "port" && network_port)
        entry_from_dialog = {}
        entry_from_dialog[:network_id] = cloud_network.id if cloud_network_selection_method == "network"
        entry_from_dialog[:port_id] = network_port.id if cloud_network_selection_method == "port"
        networks[0] ||= entry_from_dialog
      end

      options[:networks] = convert_networks_to_openstack_nics(networks)
    end
  end

  private

  def convert_networks_to_openstack_nics(networks)
    networks.delete_blanks.collect do |nic|
      if nic[:network_id]
        {"net_id" => CloudNetwork.find_by(:id => nic[:network_id]).ems_ref}
      elsif nic[:port_id]
        {"port_id" => NetworkPort.find_by(:id => nic[:port_id]).ems_ref}
      end
    end.compact
  end
end

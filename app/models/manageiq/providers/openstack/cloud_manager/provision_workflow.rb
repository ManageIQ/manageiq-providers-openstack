class ManageIQ::Providers::Openstack::CloudManager::ProvisionWorkflow < ::MiqProvisionCloudWorkflow
  include DialogFieldValidation

  def allowed_instance_types(_options = {})
    source                  = load_ar_obj(get_source_vm)
    flavors                 = get_targets_for_ems(source, :cloud_filter, Flavor, 'flavors')
    return {} if flavors.blank?
    if source.kind_of?(ManageIQ::Providers::Openstack::CloudManager::VolumeTemplate) || source.kind_of?(ManageIQ::Providers::Openstack::CloudManager::VolumeSnapshotTemplate)
      # no flavor requirements for booting from a volume
      minimum_disk_required = 0
      minimum_memory_required = 0
    else
      minimum_disk_required   = [source.hardware.size_on_disk.to_i, source.hardware.disk_size_minimum.to_i].max
      minimum_memory_required = source.hardware.memory_mb_minimum.to_i * 1.megabyte
    end
    flavors.each_with_object({}) do |flavor, h|
      # Allow flavors with 0 disk size: The instance will grow disk based upon image build definition
      next if flavor.root_disk_size.positive? && flavor.root_disk_size < minimum_disk_required
      next if flavor.memory         < minimum_memory_required
      h[flavor.id] = display_name_for_name_description(flavor)
    end
  end

  def allowed_cloud_tenants(_options = {})
    source = load_ar_obj(get_source_vm)
    ems = get_targets_for_ems(source, :cloud_filter, CloudTenant, 'cloud_tenants')
    ems.each_with_object({}) { |f, h| h[f.id] = f.name }
  end

  def availability_zone_to_cloud_network(src)
    load_ar_obj(src[:ems]).all_cloud_networks.each_with_object({}) do |cn, hash|
      hash[cn.id] = cloud_network_display_name(cn)
    end
  end

  def set_request_values(values)
    values[:volumes] = prepare_volumes_fields(values)
    super
  end

  def prepare_volumes_fields(values)
    # the provision dialog doesn't handle arrays,
    # so we have to hack around it to support an arbitrary
    # number of volumes being added at once.
    # This looks for volume form fields in the input, and converts
    # them into an array of hashes that can be understood
    # by prepare_volumes
    prepare_volumes = true
    volumes = []
    keys = %w(name size delete_on_terminate)
    while prepare_volumes
      new_volume = {}
      keys.each do |key|
        indexed_key = :"#{key}_#{volumes.length + 1}"
        new_volume[key.to_sym] = values[indexed_key] if values.key?(indexed_key)
      end
      if new_volume.blank? || new_volume.values.all?(&:blank?)
        prepare_volumes = false
      else
        new_volume[:size] = "1" if new_volume[:size].blank?
        new_volume[:name] = "" unless new_volume.key?(:name)
        volumes.push new_volume
      end
      new_volume[:delete_on_termination] = true if new_volume[:delete_on_terminate] == "on"
    end
    volumes
  end

  def allowed_floating_ip_addresses(_options = {})
    # We want to show only floating IPs connected to the cloud_network via router, respecting the owner tenant of the
    # floating ip
    return {} unless (src_obj = load_ar_obj(resources_for_ui[:cloud_network]))

    return {} unless (public_networks = src_obj.public_networks)

    public_networks.collect do |x|
      floating_ips = x.floating_ips.available
      if (cloud_tenant = load_ar_obj(resources_for_ui[:cloud_tenant]))
        floating_ips = floating_ips.where(:cloud_tenant => cloud_tenant)
      end
      floating_ips
    end.flatten.compact.each_with_object({}) do |ip, h|
      h[ip.id] = ip.address
    end
  end

  def allowed_cloud_networks(_options = {})
    return {} unless (src = provider_or_tenant_object)
    targets = get_targets_for_source(src, :cloud_filter, CloudNetwork, 'all_cloud_networks')
    targets = filter_cloud_networks(targets)
    allowed_ci(:cloud_network, [:availability_zone], targets.map(&:id))
  end

  def allowed_network_ports(_options = {})
    return {} unless (src = provider_or_tenant_object)
    cloud_networks = get_targets_for_source(src, :cloud_filter, CloudNetwork, 'all_cloud_networks')
    network_ports = []
    cloud_networks.each do |cloud_network|
      cloud_network.cloud_subnets.each do |cloud_subnet|
        network_ports.push(*cloud_subnet.network_ports.where(:device_owner => [nil, ""]).to_a)
      end
    end
    network_ports.each_with_object({}) do |port, h|
      h[port.id] = "#{port.name} (#{port.fixed_ip_addresses.first})"
    end
  end

  def allowed_availability_zones(_options = {})
    source = load_ar_obj(get_source_vm)
    targets = get_targets_for_ems(source, :cloud_filter, AvailabilityZone, 'availability_zones.available')
    targets.each_with_object({}) { |az, h| h[az.id] = az.name if az.provider_services_supported.include?("compute") }
  end

  def self.provider_model
    ManageIQ::Providers::Openstack::CloudManager
  end

  private

  def dialog_name_from_automate(message = 'get_dialog_name', extra_attrs = {})
    extra_attrs['platform'] ||= 'openstack'
    super(message, extra_attrs)
  end

  def filter_cloud_networks(networks)
    networks.select do |cloud_network|
      cloud_network.cloud_subnets.any?
    end
  end
end

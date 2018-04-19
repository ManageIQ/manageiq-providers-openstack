class ManageIQ::Providers::Openstack::CloudManager::CloudResourceQuota < ::CloudResourceQuota
  private

  # quota_used methods defined for each known quota type
  # if no method is provided for a quota type, then -1 is returned by
  # method_missing (see parent)

  VMS_POWER_FILTER = "power_state != 'unknown'"

  def cores_quota_used
    Hardware.joins(:vm)
      .where(:vms => {:cloud_tenant_id => cloud_tenant_id})
      .where("vms.#{VMS_POWER_FILTER}")
      .sum(:cpu_total_cores)
  end

  def instances_quota_used
    cloud_tenant.vms.where(VMS_POWER_FILTER).count
  end

  def ram_quota_used
    Hardware.joins(:vm)
      .where(:vms => {:cloud_tenant_id => cloud_tenant_id})
      .where("vms.#{VMS_POWER_FILTER}")
      .sum(:memory_mb)
  end

  # nova
  def floating_ips_quota_used
    # in reality, nova should not use the same quota used value as neutron ...
    # instead, if neutron is being used for networking (i.e., ems has network
    # service available), then show 0
    floatingip_quota_used
  end

  # neutron
  def floatingip_quota_used
    ::FloatingIp.where(:cloud_tenant_id => cloud_tenant_id).count
  end

  # nova
  def security_group_rules_quota_used
    # in reality, nova should not use the same quota used value as neutron ...
    # instead, if neutron is being used for networking (i.e., ems has network
    # service available), then show 0
    security_group_rule_quota_used
  end

  # neutron
  def security_group_rule_quota_used
    join = "inner join security_groups on security_groups.id = firewall_rules.resource_id "
    join += "and firewall_rules.resource_type = 'SecurityGroup'"
    FirewallRule.joins(join)
      .where("security_groups.cloud_tenant_id" => cloud_tenant_id)
      .count
  end

  # nova
  def security_groups_quota_used
    # in reality, nova should not use the same quota used value as neutron ...
    # instead, if neutron is being used for networking (i.e., ems has network
    # service available), then show 0
    security_group_quota_used
  end

  # neutron
  def security_group_quota_used
    SecurityGroup.where(:cloud_tenant_id => cloud_tenant_id).count
  end

  def network_quota_used
    CloudNetwork.where(:cloud_tenant_id => cloud_tenant_id).count
  end

  def subnet_quota_used
    CloudSubnet.joins(:cloud_network).where("cloud_networks.cloud_tenant_id" => cloud_tenant_id).count
  end

  def port_quota_used
    NetworkPort.where(:cloud_tenant_id => cloud_tenant_id).count
  end

  def volumes_quota_used
    CloudVolume.where(:cloud_tenant_id => cloud_tenant_id).count
  end

  def gigabytes_quota_used
    CloudVolume.where(:cloud_tenant_id => cloud_tenant_id)
               .sum(:size) / 1_073_741_824
  end

  def per_volume_gigabytes_quota_used
    max_used = CloudVolume.where(:cloud_tenant_id => cloud_tenant_id)
                          .maximum(:size)
    max_used.nil? ? 0 : max_used / 1_073_741_824
  end

  def backups_quota_used
    CloudVolumeBackup.joins(:cloud_volume)
                     .where("cloud_volumes.cloud_tenant_id" => cloud_tenant_id).count
  end

  def backup_gigabytes_quota_used
    CloudVolumeBackup.joins(:cloud_volume)
                     .where("cloud_volumes.cloud_tenant_id" => cloud_tenant_id)
                     .sum(:size) / 1_073_741_824
  end

  def snapshots_quota_used
    CloudVolumeSnapshot.where(:cloud_tenant_id => cloud_tenant_id).count
  end

  def ems
    CloudTenant.find(cloud_tenant_id).ext_management_system
  end

  def key_pairs_quota_used
    Authentication.where(:resource_id   => ems.id,
                         :resource_type => 'ExtManagementSystem',
                         :type          => ManageIQ::Providers::Openstack::CloudManager::AuthKeyPair.name).count
  end

  def router_quota_used
    NetworkRouter.where(:cloud_tenant_id => cloud_tenant_id).count
  end
end

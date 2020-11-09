class ManageIQ::Providers::Openstack::Inventory::Parser::StorageManager::CinderManager < ManageIQ::Providers::Openstack::Inventory::Parser
  def parse
    cloud_volumes
    cloud_volume_snapshots
    cloud_volume_backups
    cloud_volume_types
  end

  def cloud_volumes
    collector.cloud_volumes.each do |v|
      volume = persister.cloud_volumes.find_or_build(v.id)

      volume.name = volume_name(v).blank? ? v.id : volume_name(v)
      volume.status = v.status
      volume.bootable = v.attributes['bootable']
      volume.creation_time = v.created_at
      volume.description = volume_description(v)
      volume.volume_type = v.volume_type
      volume.size = v.size.to_i.gigabytes
      volume.encrypted = v.attributes['encrypted']
      volume.multi_attachment = v.attributes['multiattach']
      volume.base_snapshot = persister.cloud_volume_snapshots.lazy_find(v.snapshot_id)
      volume.cloud_tenant = persister.cloud_tenants.lazy_find(v.tenant_id)
      volume.availability_zone = persister.availability_zones.lazy_find(v.availability_zone)

      volume_attachments(volume, v.attachments)
    end
  end

  def cloud_volume_snapshots
    collector.cloud_volume_snapshots.each do |s|
      snapshot = persister.cloud_volume_snapshots.find_or_build(s['id'])

      snapshot.creation_time = s['created_at']
      snapshot.status = s['status']
      snapshot.size = s['size'].to_i.gigabytes
      # Supporting both Cinder v1 and Cinder v2
      snapshot.name = s['display_name'] || s['name']
      snapshot.description = s['display_description'] || s['description']
      snapshot.cloud_volume = persister.cloud_volumes.lazy_find(s['volume_id'])
      snapshot.cloud_tenant = persister.cloud_tenants.lazy_find(s['os-extended-snapshot-attributes:project_id'])
    end
  end

  def cloud_volume_backups
    collector.cloud_volume_backups.each do |b|
      backup = persister.cloud_volume_backups.find_or_build(b['id'])

      backup.status = b['status']
      backup.creation_time = b['create_at']
      backup.size = b['size'].to_i.gigabytes
      backup.object_count = b['object_count'].to_i
      backup.is_incremental = b['is_incremental']
      backup.has_dependent_backups = b['has_dependent_backups']
      # Supporting both Cinder v1 and Cinder v2
      backup.name = b['display_name'] || b['name']
      backup.description = b['display_description'] || b['description']
      backup.cloud_volume = persister.cloud_volumes.lazy_find(b['volume_id'])
      backup.availability_zone = persister.availability_zones.lazy_find(b['availability_zone'])
    end
  end

  def cloud_volume_types
    collector.cloud_volume_types.each do |t|
      volume_type = persister.cloud_volume_types.find_or_build(t.id)

      volume_type.name = t.name
      if t.extra_specs.present?
        volume_type.backend_name = t.extra_specs["volume_backend_name"]
      end
      volume_type.description = t.attributes["description"]
      volume_type.public = t.attributes["is_public"]
    end
  end

  def volume_attachments(persister_volume, attachments)
    (attachments || []).each do |a|
      if a['device'].blank?
        log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{ems.name}] id: [#{ems.id}]"
        _log.warn("#{log_header}: Volume: #{persister_volume.ems_ref}, is missing a mountpoint, skipping the volume processing")
        _log.warn("#{log_header}: EMS: #{ems.name}, Instance: #{a['server_id']}")
        next
      end

      dev = File.basename(a['device'])

      attachment_names = {'vda' => 'Root disk', 'vdb' => 'Ephemeral disk', 'vdc' => 'Swap disk'}
      persister.disks.find_or_build_by(
        :hardware    => persister.hardwares.lazy_find(persister.vms.lazy_find(a["server_id"])),
        :device_name => attachment_names.fetch(dev, dev)
      ).assign_attributes(
        :location        => dev,
        :size            => persister_volume.size,
        :device_type     => "disk",
        :controller_type => "openstack",
        :backing         => persister_volume
      )
    end
  end

  def volume_name(volume)
    # Cinder v1 : Cinder v2
    volume.respond_to?(:display_name) ? volume.display_name : volume.name
  end

  def volume_description(volume)
    # Cinder v1 : Cinder v2
    volume.respond_to?(:display_description) ? volume.display_description : volume.description
  end
end

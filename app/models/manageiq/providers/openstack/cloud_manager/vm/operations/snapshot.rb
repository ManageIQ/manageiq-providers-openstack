module ManageIQ::Providers::Openstack::CloudManager::Vm::Operations::Snapshot
  extend ActiveSupport::Concern

  included do
    supports :snapshot_create do
      unless supports_control?
        unsupported_reason_add(:snapshot_create, unsupported_reason(:control))
      end
    end

    supports :remove_snapshot do
      if supports_snapshots?
        if snapshots.size <= 0
          unsupported_reason_add(:remove_snapshot, _("No snapshots available for this VM"))
        end
        unless supports_control?
          unsupported_reason_add(:remove_snapshot, unsupported_reason(:control))
        end
      else
        unsupported_reason_add(:remove_snapshot, _("Operation not supported"))
      end
    end

    supports :remove_all_snapshots do
      unless supports_remove_snapshot?
        unsupported_reason_add(:remove_all_snapshots, unsupported_reason(:remove_snapshot))
      end
    end

    supports :remove_snapshot_by_description do
      unsupported_reason_add(:remove_snapshot_by_description, _("Operation not supported"))
    end

    supports :revert_to_snapshot do
      unsupported_reason_add(:revert_to_snapshot, _("Operation not supported"))
    end
  end

  def raw_create_snapshot(name, desc = nil, memory)
    run_command_via_parent(:vm_create_snapshot, :name => name, :desc => desc, :memory => memory)
  rescue => err
    create_notification(:vm_snapshot_failure, :error => err.to_s, :snapshot_op => "create")
    raise MiqException::MiqVmSnapshotError, err.to_s
  end

  def raw_remove_snapshot(snapshot_id)
    raise MiqException::MiqVmError, unsupported_reason(:remove_snapshot) unless supports_remove_snapshot?
    snapshot = snapshots.find_by(:id => snapshot_id)
    raise _("Requested VM snapshot not found, unable to remove snapshot") unless snapshot
    begin
      _log.info("removing snapshot ID: [#{snapshot.id}] uid_ems: [#{snapshot.uid_ems}] ems_ref: [#{snapshot.ems_ref}] name: [#{snapshot.name}] description [#{snapshot.description}]")

      run_command_via_parent(:vm_remove_snapshot, :snMor => snapshot.uid_ems)
    rescue => err
      create_notification(:vm_snapshot_failure, :error => err.to_s, :snapshot_op => "remove")
      if err.to_s.include?('not found')
        raise MiqException::MiqVmSnapshotError, err.to_s
      else
        raise
      end
    end
  end

  def raw_remove_all_snapshots
    raise MiqException::MiqVmError, unsupported_reason(:remove_all_snapshots) unless supports_remove_all_snapshots?
    run_command_via_parent(:vm_remove_all_snapshots)
  end
end

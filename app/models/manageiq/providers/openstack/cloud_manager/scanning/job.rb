class ManageIQ::Providers::Openstack::CloudManager::Scanning::Job < VmScan
  # Make updates to default state machine to take into account snapshots
  def load_transitions
    super.tap do |transactions|
      transactions.merge!(
        :start_snapshot     => {'before_scan'               => 'snapshot_create'},
        :snapshot_complete  => {'snapshot_create'           => 'scanning',
                                'snapshot_delete'           => 'synchronizing'},
        :snapshot_delete    => {'scanning'                  => 'snapshot_delete'},
        :data               => {'snapshot_create'           => 'scanning',
                                'scanning'                  => 'scanning',
                                'snapshot_delete'           => 'snapshot_delete',
                                'synchronizing'             => 'synchronizing',
                                'finished'                  => 'finished'}
      )
    end
  end

  def before_scan
    signal(:start_snapshot)
  end

  def call_snapshot_create
    _log.info("Enter")

    begin
      context[:snapshot_mor] = nil

      options[:snapshot] = :skipped
      options[:use_existing_snapshot] = false
      return unless create_snapshot
      signal(:snapshot_complete)
    rescue Timeout::Error
      msg = case options[:snapshot]
            when :smartProxy, :skipped then "Request to log snapshot user event with EMS timed out."
            else "Request to create snapshot timed out"
            end
      _log.error(msg)
      signal(:abort, msg, "error")
    rescue => err
      _log.log_backtrace(err)
      signal(:abort, err.message, "error")
    end
  end

  def call_snapshot_delete
    _log.info("Enter")

    # TODO: remove snapshot here if Vm was running
    if context[:snapshot_mor]
      mor = context[:snapshot_mor]
      context[:snapshot_mor] = nil

      if options[:snapshot] == :smartProxy
        set_status("Snapshot delete was performed by the SmartProxy")
      else
        set_status("Deleting VM snapshot: reference: [#{mor}]")
      end

      if vm.ext_management_system
        _log.info("Deleting snapshot: reference: [#{mor}]")
        begin
          delete_snapshot(mor)
        rescue Timeout::Error
          msg = "Request to delete snapshot timed out"
          _log.error(msg)
          return
        rescue => err
          _log.error(err.to_s)
          return
        end

        unless options[:snapshot] == :smartProxy
          _log.info("Deleted snapshot: reference: [#{mor}]")
          set_status("Snapshot deleted: reference: [#{mor}]")
        end
      else
        _log.error("Deleting snapshot: reference: [#{mor}], No Providers available to delete snapshot")
        set_status("No Providers available to delete snapshot, skipping", "error")
      end
    else
      set_status("Snapshot was not taken, delete not required") if options[:snapshot] == :skipped
      log_end_user_event_message
    end

    signal(:snapshot_complete)
  end

  def process_cancel(*args)
    begin
      delete_snapshot_and_reset_snapshot_mor("canceling")
      super
      rescue => err
      _log.log_backtrace(err)
    end

    super
  end

  def process_abort(*args)
    begin
      delete_snapshot_and_reset_snapshot_mor("aborting")
      super
    rescue => err
      _log.log_backtrace(err)
    end

    super
  end

  def snapshot_complete
    if state == 'scanning'
      scanning
      call_scan
    else
      call_synchronize
    end
  end


  # All other signals
  alias_method :start_snapshot,     :call_snapshot_create
  alias_method :snapshot_delete,    :call_snapshot_delete

  private

  def create_snapshot
    if vm.ext_management_system
      sn_description = snapshotDescription
      _log.info("Creating snapshot, description: [#{sn_description}]")
      log_start_user_event_message
      options[:snapshot] = :server
      begin
        # TODO: should this be a vm method?
        sn = vm.ext_management_system.vm_create_evm_snapshot(vm, :desc => sn_description).to_s
      rescue Exception => err
        msg = "Failed to create evm snapshot with EMS. Error: [#{err.class.name}]: [#{err}]"
        _log.error(msg)
        signal(:abort, msg, "error")
        return false
      end
      context[:snapshot_mor] = sn
      _log.info("Created snapshot, reference: [#{context[:snapshot_mor]}]")
      set_status("Snapshot created: reference: [#{context[:snapshot_mor]}]")
      options[:snapshot] = :created
      options[:use_existing_snapshot] = true
      return true
    else
      signal(:abort, "No Providers available to create snapshot, skipping", "error")
      return false
    end
  end

  def delete_snapshot(mor)
    vm.ext_management_system.vm_delete_evm_snapshot(vm, mor)
  end

  def snapshotDescription(type = nil)
    Snapshot.evm_snapshot_description(jobid, type)
  end

  def delete_snapshot_and_reset_snapshot_mor(log_verb)
    unless context[:snapshot_mor].nil?
      mor = context[:snapshot_mor]
      context[:snapshot_mor] = nil
      set_status("Deleting snapshot before #{log_verb} job")
      delete_snapshot(mor)
    end
  end

end

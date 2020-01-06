describe VmScan do
  let(:miq_server) { FactoryBot.create(:miq_server) }
  let(:ems)  { FactoryBot.create(:ems_openstack) }
  let(:vm)   { FactoryBot.create(:vm_openstack, :ext_management_system => ems) }
  let(:job)  { vm.scan_job_class.create_job(:target_id => vm.id) }
  let(:snapshot_description) { "Snapshot description" }

  before do
    allow(VmOrTemplate).to receive(:find).with(vm.id).and_return(vm)
    allow(MiqServer).to receive(:my_server).and_return(miq_server)
  end

  describe "signal: start" do
    it "should start in a state of waiting_to_start" do
      expect(job.state).to eq("waiting_to_start")
    end

    it "should queue policy check" do
      q_options = {
        :miq_callback => {
          :class_name  => job.class.to_s,
          :instance_id => job.id,
          :method_name => :check_policy_complete,
          :args        => [miq_server.my_zone]
        }
      }
      inputs = {:vm => vm, :host => vm.host}
      expect(MiqEvent).to receive(:raise_evm_job_event).with(vm, {:type => "scan", :suffix => "start"}, inputs, q_options)
      job.signal(:start)
    end

    describe "#check_policy_complete" do
      it "should queue job.signal(:before_scan) after policy check completes successfully" do
        expect(MiqQueue).to receive(:put).with(
          :class_name  => job.class.to_s,
          :instance_id => job.id,
          :method_name => "signal",
          :args        => [:before_scan],
          :zone        => miq_server.my_zone,
          :role        => "smartstate"
        )
        job.check_policy_complete(miq_server.my_zone, "ok", nil, nil)
      end

      pending "should update scan profile if returned in Automate result"
    end
  end

  describe "signal: start_snapshot" do
    before do
      job.state = "before_scan"
    end

    it "calls ems#vm_create_evm_snapshot" do
      expect(ems).to receive(:vm_create_evm_snapshot).with(vm, any_args)
      job.signal(:start_snapshot)
    end

    it "signals :snapshot_complete when snapshot completes successfully" do
      allow(ems).to receive(:vm_create_evm_snapshot).and_return(snapshot_description)
      expect(job).to receive(:snapshot_complete)
      job.signal(:start_snapshot)
    end

    it "signals :abort when snapshot fails" do
      allow(ems).to receive(:vm_create_evm_snapshot).and_raise("snapshot error")
      expect(job).to receive(:abort_job)
      job.signal(:start_snapshot)
    end
  end

  describe "signal: snapshot_complete" do
    context "after start_snapshot" do
      before do
        job.state = "snapshot_create"
      end

      it "calls vm.scan_metadata" do
        allow(MiqServer).to receive(:find).and_return(nil)
        expect(vm).to receive(:scan_metadata)
        job.signal(:snapshot_complete)
      end
    end
  end

  describe "#call_snapshot_delete" do
    before do
      job.update(:state => 'snapshot_delete')
      job.context[:snapshot_mor] = snapshot_description
      expect(job).to receive(:signal).with(:snapshot_complete)
    end

    it "calls ems#vm_delete_evm_snapshot and signals :snapshot_complete" do
      expect(ems).to receive(:vm_delete_evm_snapshot).with(vm, snapshot_description)
      job.call_snapshot_delete
      expect(job.message).to eq "Snapshot deleted: reference: [#{snapshot_description}]"
    end
  end
end

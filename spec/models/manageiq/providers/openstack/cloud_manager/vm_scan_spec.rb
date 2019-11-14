describe VmScan do
  context "A single VM Scan Job on Openstack provider" do
    let(:vm) do
      vm = double("ManageIQ::Providers::Openstack::CloudManager::Vm")
      allow(vm).to receive(:kind_of?).with(ManageIQ::Providers::Openstack::CloudManager::Vm).and_return(true)
      vm
    end
    let(:job) { VmScan.new(:context => {}, :options => {}) }

    describe "#call_snapshot_create" do
      it "executes VmScan#create_snapshot and send signal :snapshot_complete" do
        allow(VmOrTemplate).to receive(:find).and_return(vm)
        expect(job).to receive(:create_snapshot).and_return(true)
        expect(job).to receive(:signal).with(:snapshot_complete)
        job.call_snapshot_create
      end
    end
  end
end

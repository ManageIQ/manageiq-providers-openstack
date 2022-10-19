describe ManageIQ::Providers::Openstack::CloudManager::Vm do
  let(:ems) { FactoryBot.create(:ems_openstack) }
  let(:tenant) { FactoryBot.create(:cloud_tenant_openstack, :ext_management_system => ems) }
  let(:vm) do
    FactoryBot.create(:vm_openstack,
                       :ext_management_system => ems,
                       :name                  => 'test',
                       :ems_ref               => 'one_id',
                       :cloud_tenant          => tenant)
  end

  let(:terminated_vm) { FactoryBot.create(:vm_openstack) }

  let(:handle) do
    double.tap do |handle|
      allow(ems).to receive(:connect).with({:service => 'Compute', :tenant_name => tenant.name}).and_return(handle)
    end
  end

  before do
    handle
  end

  describe "with more tenants" do
    let(:other_tenant) { FactoryBot.create(:cloud_tenant_openstack, :ext_management_system => ems) }
    let(:other_vm) do
      FactoryBot.create(:vm_openstack,
                         :ext_management_system => ems,
                         :name                  => 'other_test',
                         :ems_ref               => 'other_id',
                         :cloud_tenant          => other_tenant)
    end
    let(:other_handle) do
      double.tap do |other_handle|
        allow(ems).to receive(:connect).with({:service => 'Compute', :tenant_name => other_tenant.name}).and_return(other_handle)
      end
    end

    before do
      other_handle
    end

    it "uses proper tenant for connection" do
      expect(handle).to receive(:pause_server)
      expect(other_handle).to receive(:pause_server)
      vm.raw_pause
      other_vm.raw_pause
    end
  end

  describe "vm actions" do
    before { NotificationType.seed }

    context "#live_migrate" do
      it "live migrates with default options" do
        expect(handle).to receive(:live_migrate_server).with(vm.ems_ref, nil, false, false)
        vm.live_migrate
        expect(vm.power_state).to eq 'migrating'
      end

      it "live migrates with special options" do
        expect(handle).to receive(:live_migrate_server).with(vm.ems_ref, 'host_1.localdomain', true, true)
        vm.live_migrate(:hostname => 'host_1.localdomain', :disk_over_commit => true, :block_migration => true)
        expect(vm.power_state).to eq 'migrating'
      end

      it "checks live migration is supported" do
        expect(vm.supports?(:live_migrate)).to eq true
      end
    end

    context "evacuate" do
      it "evacuates with default options" do
        expect(handle).to receive(:evacuate_server).with(vm.ems_ref, nil, true, nil)
        vm.evacuate
        expect(vm.power_state).to eq 'migrating'
      end

      it "evacuates with special options" do
        expect(handle).to receive(:evacuate_server).with(vm.ems_ref, 'host_1.localdomain', false, 'blah')
        vm.evacuate(:hostname => 'host_1.localdomain', :on_shared_storage => false, :admin_password => 'blah')
        expect(vm.power_state).to eq 'migrating'
      end

      it "evacuates with special options" do
        expect(handle).to receive(:evacuate_server).with(vm.ems_ref, 'host_1.localdomain', true, nil)
        vm.evacuate(:hostname => 'host_1.localdomain', :on_shared_storage => true)
        expect(vm.power_state).to eq 'migrating'
      end

      it "returns true for querying vm if the evacuate operation is supported" do
        expect(vm.supports?(:evacuate)).to eq true
      end
    end

    context "associate floating ip" do
      it "associates with floating ip" do
        service = double
        allow(ems).to receive(:connect).and_return(service)
        expect(service).to receive(:associate_address).with(vm.ems_ref, '10.10.10.10')
        vm.associate_floating_ip('10.10.10.10')
      end

      it "checks associate_floating_ip is supported when floating ips are available" do
        expect(vm.cloud_tenant).to receive(:floating_ips).and_return([1]) # fake a floating ip being available
        expect(vm.supports?(:associate_floating_ip)).to eq true
      end

      it "checks associate_floating_ip is supported when floating ips are not available" do
        expect(vm.cloud_tenant).to receive(:floating_ips).and_return([])
        expect(vm.supports?(:associate_floating_ip)).to eq false
      end
    end

    context "disassociate floating ip" do
      it "disassociates from floating ip" do
        service = double
        allow(ems).to receive(:connect).and_return(service)
        expect(service).to receive(:disassociate_address).with(vm.ems_ref, '10.10.10.10')
        vm.disassociate_floating_ip('10.10.10.10')
      end

      it "checks disassociate_floating_ip is supported when floating ips are associated with the instance" do
        expect(vm).to receive(:floating_ips).and_return([1]) # fake a floating ip being associated
        expect(vm.supports?(:disassociate_floating_ip)).to eq true
      end

      it "checks disassociate_floating_ip is supported when no floating ips are associated with the instance" do
        expect(vm).to receive(:floating_ips).and_return([])
        expect(vm.supports?(:disassociate_floating_ip)).to eq false
      end
    end

    context "snapshot actions" do
      it "supports snapshot_create" do
        expect(vm.supports?(:snapshot_create)).to eq true
      end

      it "does not support snapshot_create on terminated VM" do
        expect(terminated_vm.supports?(:snapshot_create)).to be_falsy
      end

      it "checks remove_snapshot is supported when snapshots are associated with the instance" do
        expect(vm).to receive(:snapshots).and_return([1]) # fake a floating ip being associated
        expect(vm.supports?(:remove_snapshot)).to eq true
      end

      it "checks remove_snapshot is supported when no snapshots are associated with the instance" do
        expect(vm).to receive(:snapshots).and_return([])
        expect(vm.supports?(:remove_snapshot)).to eq false
      end

      it "does not support remove_snapshot_by_description" do
        expect(vm.supports?(:remove_snapshot_by_description)).to eq false
      end

      it "does not support revert_to_snapshot" do
        expect(vm.supports?(:revert_to_snapshot)).to eq false
      end
    end
  end

  context "#supports?" do
    let(:ems) { FactoryBot.create(:ems_openstack) }
    let(:vm)  { FactoryBot.create(:vm_openstack, :ext_management_system => ems) }
    let(:power_state_on)        { "ACTIVE" }
    let(:power_state_suspended) { "SUSPENDED" }

    context("with :start") do
      let(:state) { :start }
      include_examples "Vm operation is available when not powered on"
    end

    context("with :stop") do
      let(:state) { :stop }
      include_examples "Vm operation is available when powered on"
    end

    context("with :suspend") do
      let(:state) { :suspend }
      include_examples "Vm operation is available when powered on"
    end

    context("with :pause") do
      let(:state) { :pause }
      include_examples "Vm operation is available when powered on"
    end

    context("with :shutdown_guest") do
      let(:state) { :shutdown_guest }
      include_examples "Vm operation is not available"
    end

    context("with :standby_guest") do
      let(:state) { :standby_guest }
      include_examples "Vm operation is not available"
    end

    context("with :reboot_guest") do
      let(:state) { :reboot_guest }
      include_examples "Vm operation is available when powered on"
    end

    context("with :reset") do
      let(:state) { :reset }
      include_examples "Vm operation is available when powered on"
    end
  end

  context "when detroyed" do
    let(:ems) { FactoryBot.create(:ems_openstack) }
    let(:provider_object) do
      double("vm_openstack_provider_object", :destroy => nil).as_null_object
    end
    let(:vm)  { FactoryBot.create(:vm_openstack, :ext_management_system => ems) }

    before { NotificationType.seed }

    it "sets the raw_power_state and not state" do
      expect(vm).to receive(:with_provider_object).and_yield(provider_object)
      vm.raw_destroy
      expect(vm.raw_power_state).to eq("DELETED")
      expect(vm.state).to eq("terminated")
    end
  end

  context "when resized" do
    let(:ems) { FactoryBot.create(:ems_openstack) }
    let(:cloud_tenant) { FactoryBot.create(:cloud_tenant) }
    let(:vm) { FactoryBot.create(:vm_openstack, :ext_management_system => ems, :cloud_tenant => cloud_tenant) }
    let(:flavor) { FactoryBot.create(:flavor_openstack, :ems_ref => '2') }

    it "initiate resize process" do
      service = double
      allow(ems).to receive(:connect).and_return(service)
      expect(vm.supports?(:resize)).to be_truthy
      expect(vm.validate_resize_confirm).to be false
      expect(service).to receive(:resize_server).with(vm.ems_ref, flavor.ems_ref)
      expect(MiqQueue).to receive(:put)
      vm.resize({"flavor"=>flavor.ems_ref})
    end

    it 'confirm resize' do
      vm.raw_power_state = 'VERIFY_RESIZE'
      service = double
      allow(ems).to receive(:connect).and_return(service)
      expect(vm.supports?(:resize)).to be_falsey
      expect(vm.validate_resize_confirm).to be true
      expect(service).to receive(:confirm_resize_server).with(vm.ems_ref)
      vm.resize_confirm
    end

    it 'revert resize' do
      vm.raw_power_state = 'VERIFY_RESIZE'
      service = double
      allow(ems).to receive(:connect).and_return(service)
      expect(vm.supports?(:resize)).to be_falsey
      expect(vm.validate_resize_revert).to be true
      expect(service).to receive(:revert_resize_server).with(vm.ems_ref)
      vm.resize_revert
    end
  end

  describe "#raw_start" do
    it "sets the raw power state to 'ACTIVE'" do
      vm = FactoryBot.create(:vm_openstack,
                              :ext_management_system => ems,
                              :cloud_tenant          => tenant,
                              :raw_power_state       => "SHUTOFF")
      expect(handle).to receive(:start_server)

      vm.raw_start

      expect(vm.raw_power_state).to eq("ACTIVE")
    end
  end

  describe "#supports?(:terminate)" do
    context "when connected to a provider" do
      it "returns true" do
        expect(vm.supports?(:terminate)).to be_truthy
      end
    end

    context "when not connected to a provider" do
      let(:archived_vm) { FactoryBot.create(:vm_openstack) }

      it "returns false" do
        expect(archived_vm.supports?(:terminate)).to be_falsey
        expect(archived_vm.unsupported_reason(:terminate)).to eq("The VM is not connected to an active Provider")
      end
    end
  end
end

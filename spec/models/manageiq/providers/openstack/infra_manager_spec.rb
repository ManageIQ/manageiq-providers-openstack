describe ManageIQ::Providers::Openstack::InfraManager do
  it ".ems_type" do
    expect(described_class.ems_type).to eq('openstack_infra')
  end

  it ".description" do
    expect(described_class.description).to eq('OpenStack Platform Director')
  end

  describe ".metrics_collector_queue_name" do
    it "returns the correct queue name" do
      worker_queue = ManageIQ::Providers::Openstack::InfraManager::MetricsCollectorWorker.default_queue_name
      expect(described_class.metrics_collector_queue_name).to eq(worker_queue)
    end
  end

  context "verifying SSH keypair credentials" do
    it "verifies Openstack SSH credentials successfully when all hosts report that the credentials are valid" do
      @ems = FactoryBot.create(:ems_openstack_infra_with_authentication)
      FactoryBot.create(:host_openstack_infra, :ext_management_system => @ems, :state => "on")
      allow_any_instance_of(ManageIQ::Providers::Openstack::InfraManager::Host).to receive(:verify_credentials).and_return(true)
      expect(@ems.send(:verify_ssh_keypair_credentials, nil)).to be_truthy
    end

    it "fails to verify Openstack SSH credentials when any hosts report that the credentials are invalid" do
      @ems = FactoryBot.create(:ems_openstack_infra_with_authentication)
      host = FactoryBot.create(:host_openstack_infra, :ext_management_system => @ems, :state => "on")
      allow_any_instance_of(ManageIQ::Providers::Openstack::InfraManager::Host).to receive(:verify_credentials).and_return(false)
      expect(@ems.send(:verify_ssh_keypair_credentials, nil)).to be_falsey
    end

    it "disregards powered off hosts when verifying Openstack SSH credentials" do
      @ems = FactoryBot.create(:ems_openstack_infra_with_authentication)
      FactoryBot.create(:host_openstack_infra, :ext_management_system => @ems, :state => "off")
      allow_any_instance_of(ManageIQ::Providers::Openstack::InfraManager::Host).to receive(:verify_credentials).and_return(false)
      expect(@ems.send(:verify_ssh_keypair_credentials, nil)).to be_truthy
    end

    it "disregards host with no ems_cluster" do
      @ems = FactoryBot.create(:ems_openstack_infra_with_authentication)
      FactoryBot.create(:host_openstack_infra, :ext_management_system => @ems, :state => "on", :ems_cluster => nil)
      allow_any_instance_of(ManageIQ::Providers::Openstack::InfraManager::Host).to receive(:verify_credentials).and_return(false)
      expect(@ems.send(:verify_ssh_keypair_credentials, nil)).to be_truthy
    end
  end

  context "validation" do
    before :each do
      @ems = FactoryBot.create(:ems_openstack_infra_with_authentication)
      require 'manageiq/providers/openstack/legacy/openstack_event_monitor'
    end

    it "verifies AMQP credentials" do
      EvmSpecHelper.stub_amqp_support

      creds = {}
      creds[:amqp] = {:userid => "amqp_user", :password => "amqp_password"}
      @ems.endpoints << Endpoint.create(:role => 'amqp', :hostname => 'amqp_hostname', :port => '5672')
      @ems.update_authentication(creds, :save => false)
      expect(@ems.verify_credentials(:amqp)).to be_truthy
    end

    it "indicates that an event monitor is available" do
      allow(OpenstackEventMonitor).to receive(:available?).and_return(true)
      expect(@ems.event_monitor_available?).to be_truthy
    end

    it "indicates that an event monitor is not available" do
      allow(OpenstackEventMonitor).to receive(:available?).and_return(false)
      expect(@ems.event_monitor_available?).to be_falsey
    end

    it "logs an error and indicates that an event monitor is not available when there's an error checking for an event monitor" do
      allow(OpenstackEventMonitor).to receive(:available?).and_raise(StandardError)
      expect($log).to receive(:error).with(/Exception trying to find openstack event monitor/)
      expect($log).to receive(:error)
      expect(@ems.event_monitor_available?).to be_falsey
    end
  end

  context "provider hooks" do
    before do
      @ems = FactoryBot.create(:ems_openstack_infra_with_authentication)
    end

    it "creates related ProviderOpenstack after creating EmsOpenstackInfra" do
      expect(@ems.provider.name).to eq @ems.name
      expect(@ems.provider.zone).to eq(@ems.zone)
      expect(ManageIQ::Providers::Openstack::Provider.count).to eq 1
    end

    it "destroys related ProviderOpenstack after destroying EmsOpenstackInfra" do
      expect(ManageIQ::Providers::Openstack::Provider.count).to eq 1
      @ems.destroy
      expect(ManageIQ::Providers::Openstack::Provider.count).to eq 0
    end

    it "related EmsOpenstack nullifies relation to ProviderOpenstack on EmsOpenstackInfra destroy" do
      # add ems_cloud relation to @ems
      @ems_cloud = FactoryBot.create(:ems_openstack_with_authentication)
      @ems.provider.cloud_ems << @ems_cloud

      # compare they both use the same provider
      expect(@ems_cloud.provider).to eq(@ems.provider)

      @ems.destroy
      expect(ManageIQ::Providers::Openstack::InfraManager.count).to eq 0
      expect(ManageIQ::Providers::Openstack::Provider.count).to eq 0

      # Ensure the ems_cloud still stays around
      expect(ManageIQ::Providers::Openstack::CloudManager.count).to eq 1
      expect(@ems_cloud.reload.provider).to be_nil
    end
  end

  context "cloud disk usage" do
    before do
      @provider = FactoryBot.create(:provider_openstack, :name => "undercloud")
      @cloud = FactoryBot.create(:ems_openstack, :name => "overcloud", :provider => @provider)
      @infra = FactoryBot.create(:ems_openstack_infra_with_stack, :name => "undercloud", :provider => @provider)
      @cluster = FactoryBot.create(:ems_cluster_openstack, :ext_management_system => @infra)
    end

    it "Block Storage / Cinder" do
      expect(@cluster.cloud_block_storage_disk_usage).to eq(0)

      @cloud.cloud_volumes << FactoryBot.create(:cloud_volume_openstack, :size => 11, :status => "noterror")
      @cloud.cloud_volumes << FactoryBot.create(:cloud_volume_openstack, :size => 50, :status => "error")

      expect(@cluster.cloud_block_storage_disk_usage).to eq(11)
    end

    it "Object Storage / Swift" do
      stack = FactoryBot.create(:orchestration_stack_openstack_infra, :name => "overcloud")
      stack.parameters << FactoryBot.create(:orchestration_stack_parameter_openstack_infra, :name => "SwiftReplicas", :value => 3)
      stack.parameters << FactoryBot.create(:orchestration_stack_parameter_openstack_infra, :name => "ObjectStorageCount", :value => 2)
      @infra.orchestration_stacks << stack

      expect(@cluster.cloud_object_storage_disk_usage).to eq(0)

      container = FactoryBot.create(:cloud_object_store_container, :bytes => 12)
      @cloud.cloud_object_store_containers << container

      expect(@cluster.cloud_object_storage_disk_usage).to eq(12 * 2)
    end
  end

  context "catalog types" do
    let(:ems) { FactoryBot.create(:ems_openstack_infra_with_authentication) }

    it "#catalog_types" do
      expect(ems.catalog_types).to include("openstack")
    end
  end

  let(:openstack_infra_manager) { FactoryBot.create(:ems_openstack_infra_with_authentication) }

  it 'returns empty relation instead of nil when cloud_tenants are requested on infra provider' do
    expect(openstack_infra_manager.cloud_tenants).to eq(ManageIQ::Providers::Openstack::InfraManager.none)
  end
end

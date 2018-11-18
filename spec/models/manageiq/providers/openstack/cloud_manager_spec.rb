describe ManageIQ::Providers::Openstack::CloudManager do
  context "Class Methods" do
    it("from mixin") { expect(described_class.methods).to include(:raw_connect) }
  end

  it ".ems_type" do
    expect(described_class.ems_type).to eq('openstack')
  end

  it ".description" do
    expect(described_class.description).to eq('OpenStack')
  end

  it "moves the child managers to the same zone and provider region as the cloud_manager" do
    zone1 = FactoryGirl.create(:zone)
    zone2 = FactoryGirl.create(:zone)

    ems = FactoryGirl.create(:ems_openstack, :zone => zone1, :provider_region => "region1")
    expect(ems.network_manager.zone).to eq zone1
    expect(ems.network_manager.zone_id).to eq zone1.id
    expect(ems.network_manager.provider_region).to eq "region1"

    expect(ems.cinder_manager.zone).to eq zone1
    expect(ems.cinder_manager.zone_id).to eq zone1.id
    expect(ems.cinder_manager.provider_region).to eq "region1"

    expect(ems.swift_manager.zone).to eq zone1
    expect(ems.swift_manager.zone_id).to eq zone1.id
    expect(ems.swift_manager.provider_region).to eq "region1"

    ems.zone = zone2
    ems.provider_region = "region2"
    ems.save!
    ems.reload

    expect(ems.network_manager.zone).to eq zone2
    expect(ems.network_manager.zone_id).to eq zone2.id
    expect(ems.network_manager.provider_region).to eq "region2"

    expect(ems.cinder_manager.zone).to eq zone2
    expect(ems.cinder_manager.zone_id).to eq zone2.id
    expect(ems.cinder_manager.provider_region).to eq "region2"

    expect(ems.swift_manager.zone).to eq zone2
    expect(ems.swift_manager.zone_id).to eq zone2.id
    expect(ems.swift_manager.provider_region).to eq "region2"
  end

  describe ".metrics_collector_queue_name" do
    it "returns the correct queue name" do
      worker_queue = ManageIQ::Providers::Openstack::CloudManager::MetricsCollectorWorker.default_queue_name
      expect(described_class.metrics_collector_queue_name).to eq(worker_queue)
    end
  end

  describe ".raw_connect" do
    before do
      require 'manageiq/providers/openstack/legacy/openstack_handle/handle'
    end

    it "accepts and decrypts encrypted passwords" do
      params = {
        :name                      => 'dummy',
        :provider_region           => '',
        :api_version               => 'v2.0',
        :default_security_protocol => 'non-ssl',
        :default_userid            => 'admin',
        :default_hostname          => 'address',
        :default_api_port          => '5000'
      }
      expect(OpenstackHandle::Handle).to receive(:raw_connect).with(
        "admin",
        "dummy",
        "http://address:5000",
        "Compute",
        instance_of(Hash)
      )

      described_class.raw_connect(MiqPassword.encrypt("dummy"), params, "Compute")
    end

    it "works with unencrypted passwords" do
      params = {
        :name                      => 'dummy',
        :provider_region           => '',
        :api_version               => 'v2.0',
        :default_security_protocol => 'non-ssl',
        :default_userid            => 'admin',
        :default_hostname          => 'address',
        :default_api_port          => '5000'
      }
      expect(OpenstackHandle::Handle).to receive(:raw_connect).with(
        "admin",
        "dummy",
        "http://address:5000",
        "Compute",
        instance_of(Hash)
      )

      described_class.raw_connect("dummy", params, "Compute")
    end
  end

  context "validation" do
    before :each do
      @ems = FactoryGirl.create(:ems_openstack_with_authentication)
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
      expect($log).to receive(:error).with(/Exception trying to find openstack event monitor./)
      expect($log).to receive(:error)
      expect(@ems.event_monitor_available?).to be_falsey
    end

    it "fails uniqueness check for same hostname with same or without domains and regions" do
      dup_ems = FactoryGirl.build(:ems_openstack_with_authentication)
      taken_hostname = @ems.endpoints.first.hostname
      dup_ems.endpoints.first.hostname = taken_hostname
      expect(dup_ems.valid?).to be_falsey
    end

    it "passes uniqueness check for same hostname with different domain" do
      dup_ems = FactoryGirl.build(:ems_openstack_with_authentication, :uid_ems => 'my_domain')
      taken_hostname = @ems.endpoints.first.hostname
      dup_ems.endpoints.first.hostname = taken_hostname
      expect(dup_ems.valid?).to be_truthy
    end

    it "passes uniqueness check for same hostname with different region" do
      dup_ems = FactoryGirl.build(:ems_openstack_with_authentication, :provider_region => 'RegionTwo')
      taken_hostname = @ems.endpoints.first.hostname
      dup_ems.endpoints.first.hostname = taken_hostname
      expect(dup_ems.valid?).to be_truthy
    end

    it "passes uniqueness check for same hostname with different domain and region" do
      dup_ems = FactoryGirl.build(:ems_openstack_with_authentication,
                                  :uid_ems => 'my_domain', :provider_region => 'RegionTwo')
      taken_hostname = @ems.endpoints.first.hostname
      dup_ems.endpoints.first.hostname = taken_hostname
      expect(dup_ems.valid?).to be_truthy
    end
  end

  context "provider hooks" do
    it "related EmsOpenstack and ProviderOpenstack are left around on EmsOpenstackCloud destroy" do
      @ems = FactoryGirl.create(:ems_openstack_infra_with_authentication)
      @ems_cloud = FactoryGirl.create(:ems_openstack_with_authentication)
      @ems.provider.cloud_ems << @ems_cloud

      # compare they both use the same provider
      expect(@ems_cloud.provider).to eq(@ems.provider)

      @ems_cloud.destroy
      expect(ManageIQ::Providers::Openstack::CloudManager.count).to eq 0

      # Ensure the ems infra and provider still stays around
      expect(ManageIQ::Providers::Openstack::Provider.count).to eq 1
      expect(ManageIQ::Providers::Openstack::InfraManager.count).to eq 1
    end
  end

  it "event_monitor_options with 1 amqp hostname" do
    allow(ManageIQ::Providers::Openstack::CloudManager::EventCatcher).to receive_messages(:worker_settings => {:amqp_port => 1234})
    @ems = FactoryGirl.build(:ems_openstack, :hostname => "host", :ipaddress => "::1")
    @ems.endpoints << Endpoint.create(:role => 'amqp', :hostname => 'amqp_hostname', :port => '5672')
    require 'manageiq/providers/openstack/legacy/openstack_event_monitor'

    expect(@ems.event_monitor_options[:hostname]).to eq("amqp_hostname")
    expect(@ems.event_monitor_options[:port]).to eq(5672)
  end

  it "event_monitor_options with multiple amqp hostnames" do
    allow(ManageIQ::Providers::Openstack::CloudManager::EventCatcher).to receive_messages(:worker_settings => {:amqp_port => 1234})
    @ems = FactoryGirl.build(:ems_openstack, :hostname => "host", :ipaddress => "::1")
    @ems.endpoints << Endpoint.create(:role => 'amqp', :hostname => 'amqp_hostname', :port => '5672')
    @ems.endpoints << Endpoint.create(:role => 'amqp_fallback1', :hostname => 'amqp_fallback_hostname1', :port => '5672')
    @ems.endpoints << Endpoint.create(:role => 'amqp_fallback2', :hostname => 'amqp_fallback_hostname2', :port => '5672')
    require 'manageiq/providers/openstack/legacy/openstack_event_monitor'

    expect(@ems.event_monitor_options[:hostname]).to eq("amqp_hostname")
    expect(@ems.event_monitor_options[:amqp_fallback_hostname1]).to eq("amqp_fallback_hostname1")
    expect(@ems.event_monitor_options[:amqp_fallback_hostname2]).to eq("amqp_fallback_hostname2")
    expect(@ems.event_monitor_options[:port]).to eq(5672)
  end

  context "translate_exception" do
    it "preserves and logs message for unknown exceptions" do
      ems = FactoryGirl.build(:ems_openstack, :hostname => "host", :ipaddress => "::1")

      creds = {:default => {:userid => "fake_user", :password => "fake_password"}}
      ems.update_authentication(creds, :save => false)

      allow(ems).to receive(:with_provider_connection).and_raise(StandardError, "unlikely")

      expect($log).to receive(:error).with(/unlikely/)
      expect { ems.verify_credentials }.to raise_error(MiqException::MiqEVMLoginError, /Unexpected.*unlikely/)
    end
  end

  context "availability zone disk usage" do
    before do
      @provider = FactoryGirl.create(:provider_openstack, :name => "undercloud")
      @infra = FactoryGirl.create(:ems_openstack_infra_with_stack, :name => "undercloud", :provider => @provider)
      @cloud = FactoryGirl.create(:ems_openstack, :name => "overcloud", :provider => @provider)
      @az = FactoryGirl.create(:availability_zone_openstack, :ext_management_system => @cloud, :name => "nova")
      @cluster = FactoryGirl.create(:ems_cluster_openstack, :ext_management_system => @infra, :name => "BlockStorage")
      @host = FactoryGirl.create(:host_openstack_infra)
      @cluster.hosts << @host
      expect(@az.block_storage_disk_usage).to eq(0)
    end

    it "block storage disk capacity" do
      expect(@az.block_storage_disk_capacity).to eq(0)
      FactoryGirl.create(:hardware, :disk_capacity => "7", :host => @host)
      expect(@az.block_storage_disk_capacity).to eq(7)
    end

  end

  context "catalog types" do
    let(:ems) { FactoryGirl.create(:ems_openstack) }

    it '#supported_catalog_types' do
      expect(ems.supported_catalog_types).to eq(%w(openstack))
    end
  end
end

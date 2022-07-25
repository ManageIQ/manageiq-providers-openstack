describe ManageIQ::Providers::Openstack::CloudManager::Refresher do
  include Spec::Support::EmsRefreshHelper

  before(:each) do
    host = Rails.application.secrets.openstack[:hostname]
    port = Rails.application.secrets.openstack[:port]
    username = Rails.application.secrets.openstack[:userid]
    password = Rails.application.secrets.openstack[:password]

    zone = EvmSpecHelper.local_miq_server.zone
    @ems = FactoryBot.create(:ems_openstack, :zone => zone, :hostname => host,
                              :ipaddress => host, :port => port, :api_version => 'v3',
                              :security_protocol => 'ssl-no-validation', :uid_ems => "default")

    credentials = {:userid => username, :password => password}
    @ems.authentications << FactoryBot.create(:authentication, credentials)
  end

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:openstack)
  end

  it "will perform a full refresh" do
    inventory = nil
    2.times do # Run twice to verify that a second run with existing data does not change anything
      with_vcr do
        @ems.refresh

        @ems.network_manager.refresh

        @ems.cinder_manager.refresh

        @ems.swift_manager.refresh
      end

      inventory ? assert_inventory_not_changed { inventory } : inventory = serialize_inventory
      @ems.reload

      assert_specific_vm
      assert_specific_auth_key_pair
      assert_specific_cloud_volume
      assert_specific_host_aggregates
      assert_specific_cloud_network
      assert_specific_cloud_subnet
      assert_specific_security_group
      assert_specific_network_router
    end
  end

  def assert_specific_vm
    vm = @ems.vms.find_by(:name => "test-server")
    expect(vm.name).to eq("test-server")
    expect(vm.connection_state).to eq("connected")
    expect(vm.type).to eq("ManageIQ::Providers::Openstack::CloudManager::Vm")
  end

  def assert_specific_auth_key_pair
    key = @ems.key_pairs.find_by(:name => "test-key")
    expect(key.name).to eq("test-key")
    expect(key.type).to eq("ManageIQ::Providers::Openstack::CloudManager::AuthKeyPair")
  end

  def assert_specific_cloud_volume
    vol = @ems.cloud_volumes.find_by(:name => "test-vol")
    expect(vol.name).to eq("test-vol")
    expect(vol.status).to eq("available")
    expect(vol.volume_type).to eq("__DEFAULT__")
    expect(vol.type).to eq("ManageIQ::Providers::Openstack::StorageManager::CinderManager::CloudVolume")
  end

  def assert_specific_host_aggregates
    aggregate = @ems.host_aggregates.find_by(:name => "test-aggregate")
    expect(aggregate.name).to eq("test-aggregate")
    expect(aggregate.type).to eq("ManageIQ::Providers::Openstack::CloudManager::HostAggregate")
  end

  def assert_specific_cloud_network
    cn = @ems.cloud_networks.find_by(:name => "test-network")
    expect(cn.name).to eq("test-network")
    expect(cn.type).to eq("ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork")
  end

  def assert_specific_cloud_subnet
    cs = @ems.cloud_subnets.find_by(:name => "test-subnet")
    expect(cs.name).to eq("test-subnet")
    expect(cs.cidr).to eq("10.0.0.0/21")
    expect(cs.network_protocol).to eq("ipv4")
    expect(cs.type).to eq("ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet")
  end

  def assert_specific_security_group
    sg = @ems.security_groups.find_by(:name => "test-sg-group")
    expect(sg.name).to eq("test-sg-group")
    expect(sg.description).to eq("test description")
    expect(sg.type).to eq("ManageIQ::Providers::Openstack::NetworkManager::SecurityGroup")
  end

  def assert_specific_network_router
    nr = @ems.network_routers.find_by(:name => "test-router")
    expect(nr.name).to eq("test-router")
    expect(nr.admin_state_up).to eq(true)
    expect(nr.status).to eq("ACTIVE")
    expect(nr.type).to eq("ManageIQ::Providers::Openstack::NetworkManager::NetworkRouter")
  end
end

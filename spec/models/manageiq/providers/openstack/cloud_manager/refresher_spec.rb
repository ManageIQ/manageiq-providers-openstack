describe ManageIQ::Providers::Openstack::CloudManager::Refresher do
  include Spec::Support::EmsRefreshHelper

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:openstack)
  end

  context "#refresh" do
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
      @inventory = nil
    end

    def reset_cache
      @ems.reset_openstack_handle

      require "fog/openstack"
      Fog::OpenStack.instance_variable_set(:@version, nil)
    end

    def refresh_inventory(vcr_suffix = nil)
      with_vcr(vcr_suffix) do
        reset_cache

        @ems.refresh
        @ems.network_manager.refresh
        @ems.cinder_manager.refresh
        @ems.swift_manager.refresh
      end

      @inventory ? assert_inventory_not_changed { @inventory } : @inventory = serialize_inventory
      @ems.reload
    end

    def assert_common
      assert_specific_vm
      assert_specific_auth_key_pair
      assert_specific_cloud_volume
      assert_specific_host_aggregates
      assert_specific_cloud_network
      assert_specific_cloud_subnet
      assert_specific_security_group
      assert_specific_network_router
    end

    def assert_specific_vm
      vm = @ems.vms.find_by(:name => "manageiq-spec-server")
      expect(vm.name).to eq("manageiq-spec-server")
      expect(vm.connection_state).to eq("connected")
      expect(vm.type).to eq("ManageIQ::Providers::Openstack::CloudManager::Vm")
    end

    def assert_specific_auth_key_pair
      key = @ems.key_pairs.find_by(:name => "manageiq-spec-key")
      expect(key.name).to eq("manageiq-spec-key")
      expect(key.type).to eq("ManageIQ::Providers::Openstack::CloudManager::AuthKeyPair")
    end

    def assert_specific_cloud_volume
      vol = @ems.cloud_volumes.find_by(:name => "manageiq-spec-vol")
      expect(vol.name).to eq("manageiq-spec-vol")
      expect(vol.status).to eq("available")
      expect(vol.volume_type).to eq("__DEFAULT__")
      expect(vol.type).to eq("ManageIQ::Providers::Openstack::StorageManager::CinderManager::CloudVolume")
    end

    def assert_specific_host_aggregates
      aggregate = @ems.host_aggregates.find_by(:name => "manageiq-spec-aggregate")
      expect(aggregate.name).to eq("manageiq-spec-aggregate")
      expect(aggregate.type).to eq("ManageIQ::Providers::Openstack::CloudManager::HostAggregate")
    end

    def assert_specific_cloud_network
      cn = @ems.cloud_networks.find_by(:name => "manageiq-spec-network")
      expect(cn.name).to eq("manageiq-spec-network")
      expect(cn.type).to eq("ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Private")
    end

    def assert_specific_cloud_subnet
      cn = @ems.cloud_networks.find_by(:name => "manageiq-spec-network")
      cs = @ems.cloud_subnets.find_by(:cloud_network_id => cn.id)
      expect(cs.cidr).to eq("10.0.0.0/21")
      expect(cs.network_protocol).to eq("ipv4")
      expect(cs.type).to eq("ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet")
    end

    def assert_specific_security_group
      sg = @ems.security_groups.find_by(:name => "manageiq-spec-sg")
      expect(sg.name).to eq("manageiq-spec-sg")
      expect(sg.description).to eq("test description")
      expect(sg.type).to eq("ManageIQ::Providers::Openstack::NetworkManager::SecurityGroup")
    end

    def assert_specific_network_router
      nr = @ems.network_routers.find_by(:name => "manageiq-spec-router")
      expect(nr.name).to eq("manageiq-spec-router")
      expect(nr.admin_state_up).to eq(true)
      expect(nr.status).to eq("ACTIVE")
      expect(nr.type).to eq("ManageIQ::Providers::Openstack::NetworkManager::NetworkRouter")
    end

    it "will perform a full refresh" do
      2.times do # Run twice to verify that a second run with existing data does not change anything
        refresh_inventory
        assert_common
      end
    end

    context "when using an admin account for fast refresh" do
      before do
        stub_settings_merge(
          :ems_refresh => {
            :openstack         => {:is_admin => true},
            :openstack_network => {:is_admin => true}
          }
        )
      end

      it "will perform a fast full refresh" do
        2.times do
          refresh_inventory("refresher_admin")
          assert_common
        end
      end
    end

    context "targeted refresh" do
      before { refresh_inventory }

      context "targeted refresh for VM" do
        let(:target) { @ems.vms.find_by(:name => "manageiq-spec-server") }

        it "will perform a targeted VM refresh" do
          with_vcr("vm_target") do
            reset_cache
            EmsRefresh.refresh(target)
          end
          assert_specific_vm
        end
      end
    end
  end
end

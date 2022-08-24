describe ManageIQ::Providers::Openstack::CloudManager::Refresher do
  include Spec::Support::EmsRefreshHelper

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:openstack)
  end

  context "#refresh" do
    let(:zone) { EvmSpecHelper.local_miq_server.zone }
    let(:api_version) { "v3" }
    let(:keystone_domain) { "default" }
    let(:tenant_mapping) { true }
    let(:ems) do
      host = Rails.application.secrets.openstack[:hostname]
      port = Rails.application.secrets.openstack[:port]

      FactoryBot.create(:ems_openstack, :zone => zone, :hostname => host,
                        :ipaddress => host, :port => port, :api_version => api_version,
                        :security_protocol => 'ssl-no-validation', :uid_ems => keystone_domain,
                        :tenant_mapping_enabled => tenant_mapping).tap do |ems|
        username = Rails.application.secrets.openstack[:userid]
        password = Rails.application.secrets.openstack[:password]
        ems.authentications << FactoryBot.create(:authentication, {:userid => username, :password => password})
      end
    end

    it "will perform a full refresh" do
      2.times do # Run twice to verify that a second run with existing data does not change anything
        refresh_inventory
        assert_common
      end
    end

    context "with an unsupported version" do
      before do
        EmsRefresh.debug_failures = false

        allow_any_instance_of(ManageIQ::Providers::Openstack::CloudManager::Refresher)
          .to receive(:refresh_targets_for_ems).and_raise(Excon::Errors::BadRequest.new("Bad Request"))
      end

      it "will record an error" do
        expect { EmsRefresh.refresh(ems) }.to raise_error(ems.refresher::PartialRefreshError)
        expect(ems.last_refresh_status).to eq("error")
        expect(ems.last_refresh_error).to  eq("Bad Request")
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
        let(:vm) { ems.vms.find_by(:name => "manageiq-spec-server") }
        let(:target) do
          InventoryRefresh::Target.new(
            :manager     => ems,
            :association => :vms,
            :manager_ref => {:ems_ref => vm.ems_ref}
          )
        end
        let(:target) { ems.vms.find_by(:name => "manageiq-spec-server") }

        it "will perform a targeted VM refresh" do
          2.times do
            with_vcr("refresher_vm_target") do
              reset_cache
              EmsRefresh.refresh(target)
            end
            assert_specific_vm
          end
        end
      end

      context "targeted refresh for network router" do
        let(:network_router) { ems.network_routers.find_by(:name => "manageiq-spec-router") }
        let(:target) do
          InventoryRefresh::Target.new(
            :manager     => ems,
            :association => :network_routers,
            :manager_ref => {:ems_ref => network_router.ems_ref}
          )
        end

        it "will perform a targeted network router refresh" do
          2.times do
            with_vcr("refresher_router_target") do
              reset_cache
              EmsRefresh.refresh(target)
            end
            assert_specific_network_router
          end
        end
      end

      context "targeted refresh for network port" do
        let(:network_port) { ems.network_ports.find_by(:name => "manageiq-spec-port") }
        let(:target) do
          InventoryRefresh::Target.new(
            :manager     => ems,
            :association => :network_ports,
            :manager_ref => {:ems_ref => network_port.ems_ref}
          )
        end

        it "will perform a targeted network port refresh" do
          2.times do
            with_vcr("refresher_port_target") do
              reset_cache
              EmsRefresh.refresh(target)
            end
            assert_specific_network_port
          end
        end
      end

      context "targeted refresh for cloud volume" do
        let(:cloud_volume) { ems.cloud_volumes.find_by(:name => "manageiq-spec-vol") }
        let(:target) do
          InventoryRefresh::Target.new(
            :manager     => ems,
            :association => :cloud_volumes,
            :manager_ref => {:ems_ref => cloud_volume.ems_ref}
          )
        end

        it "will perform a targeted cloud volume refresh" do
          2.times do
            with_vcr("refresher_volume_target") do
              reset_cache
              EmsRefresh.refresh(target)
            end
            assert_specific_cloud_volume
          end
        end
      end

      context "targeted refresh for cloud tenant" do
        let(:cloud_tenant) { ems.cloud_tenants.find_by(:name => "manageiq-spec-project") }
        let(:target) do
          InventoryRefresh::Target.new(
            :manager     => ems,
            :association => :cloud_tenants,
            :manager_ref => {:ems_ref => cloud_tenant.ems_ref}
          )
        end

        it "will perform a targeted cloud tenant refresh" do
          2.times do
            with_vcr("refresher_tenant_target") do
              reset_cache
              EmsRefresh.refresh(target)
            end
            assert_specific_cloud_tenant
          end
        end
      end

      context "targeted refresh for cloud network" do
        let(:cloud_network) { ems.cloud_networks.find_by(:name => "manageiq-spec-network") }
        let(:target) do
          InventoryRefresh::Target.new(
            :manager     => ems,
            :association => :cloud_networks,
            :manager_ref => {:ems_ref => cloud_network.ems_ref}
          )
        end

        it "will not wipe out subnet relationships when performing a targeted network refresh" do
          with_vcr("refresher_network_target") do
            ems.cloud_subnets.each do |subnet|
              expect(subnet.cloud_network_id).to_not be(nil)
            end

            reset_cache
            EmsRefresh.refresh(target)

            ems.cloud_subnets.each do |subnet|
              expect(subnet.cloud_network_id).to_not be(nil)
            end
          end
        end
      end
    end

    def reset_cache
      ems.reset_openstack_handle

      require "fog/openstack"
      Fog::OpenStack.instance_variable_set(:@version, nil)
    end

    def refresh_inventory(vcr_suffix = nil)
      with_vcr(vcr_suffix) do
        reset_cache

        ems.refresh
        ems.network_manager.refresh
        ems.cinder_manager.refresh
        ems.swift_manager.refresh
      end

      @inventory ? assert_inventory_not_changed { @inventory } : @inventory = serialize_inventory
      ems.reload
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
      assert_specific_network_port
      assert_specific_cloud_tenant
      assert_sync_cloud_tenants
    end

    def assert_specific_vm
      vm = ems.vms.find_by(:name => "manageiq-spec-server")
      expect(vm.name).to eq("manageiq-spec-server")
      expect(vm.connection_state).to eq("connected")
      expect(vm.type).to eq("ManageIQ::Providers::Openstack::CloudManager::Vm")
    end

    def assert_specific_auth_key_pair
      key = ems.key_pairs.find_by(:name => "manageiq-spec-key")
      expect(key.name).to eq("manageiq-spec-key")
      expect(key.type).to eq("ManageIQ::Providers::Openstack::CloudManager::AuthKeyPair")
    end

    def assert_specific_cloud_volume
      vol = ems.cloud_volumes.find_by(:name => "manageiq-spec-vol")
      expect(vol.name).to eq("manageiq-spec-vol")
      expect(vol.status).to eq("available")
      expect(vol.volume_type).to eq("__DEFAULT__")
      expect(vol.type).to eq("ManageIQ::Providers::Openstack::StorageManager::CinderManager::CloudVolume")
    end

    def assert_specific_host_aggregates
      aggregate = ems.host_aggregates.find_by(:name => "manageiq-spec-aggregate")
      expect(aggregate.name).to eq("manageiq-spec-aggregate")
      expect(aggregate.type).to eq("ManageIQ::Providers::Openstack::CloudManager::HostAggregate")
    end

    def assert_specific_cloud_network
      cn = ems.cloud_networks.find_by(:name => "manageiq-spec-network")
      expect(cn.name).to eq("manageiq-spec-network")
      expect(cn.type).to eq("ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Private")
    end

    def assert_specific_cloud_subnet
      cn = ems.cloud_networks.find_by(:name => "manageiq-spec-network")
      cs = ems.cloud_subnets.find_by(:cloud_network_id => cn.id)
      expect(cs.cidr).to eq("10.0.0.0/21")
      expect(cs.network_protocol).to eq("ipv4")
      expect(cs.type).to eq("ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet")
    end

    def assert_specific_security_group
      sg = ems.security_groups.find_by(:name => "manageiq-spec-sg")
      expect(sg.name).to eq("manageiq-spec-sg")
      expect(sg.description).to eq("test description")
      expect(sg.type).to eq("ManageIQ::Providers::Openstack::NetworkManager::SecurityGroup")
    end

    def assert_specific_network_router
      nr = ems.network_routers.find_by(:name => "manageiq-spec-router")
      expect(nr.name).to eq("manageiq-spec-router")
      expect(nr.admin_state_up).to eq(true)
      expect(nr.status).to eq("ACTIVE")
      expect(nr.type).to eq("ManageIQ::Providers::Openstack::NetworkManager::NetworkRouter")
    end

    def assert_specific_network_port
      np = ems.network_ports.find_by(:name => "manageiq-spec-port")
      expect(np.name).to eq("manageiq-spec-port")
      expect(np.admin_state_up).to eq(true)
      expect(np.type).to eq("ManageIQ::Providers::Openstack::NetworkManager::NetworkPort")
    end

    def assert_specific_cloud_tenant
      ct = ems.cloud_tenants.find_by(:name => "manageiq-spec-project")
      expect(ct.name).to eq("manageiq-spec-project")
      expect(ct.description).to eq("test description")
      expect(ct.type).to eq("ManageIQ::Providers::Openstack::CloudManager::CloudTenant")
    end

    def assert_sync_cloud_tenants
      sync_cloud_tenant = MiqQueue.last
      expect(sync_cloud_tenant.method_name).to eq("sync_cloud_tenants_with_tenants")
      expect(sync_cloud_tenant.state).to eq(MiqQueue::STATE_READY)
    end
  end
end

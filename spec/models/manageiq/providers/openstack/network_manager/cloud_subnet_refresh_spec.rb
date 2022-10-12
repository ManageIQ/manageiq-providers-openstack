describe ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet do
  describe "refresh" do
    before do
      parent_ems = FactoryBot.create(:ems_openstack_with_authentication)
      @ems = parent_ems.network_manager
      EvmSpecHelper.local_miq_server(:zone => Zone.seed)
    end

    it "removes subnet link to router if the interface is deleted" do
      setup_mocked_collector

      EmsRefresh.refresh(@ems)
      expect(CloudSubnet.count).to eq(1)
      expect(CloudNetwork.count).to eq(1)
      expect(NetworkPort.count).to eq(1)
      expect(NetworkRouter.count).to eq(1)
      expect(CloudSubnet.first.network_router_id).to eq(NetworkRouter.first.id)

      # simulate the interface between a router and subnet being removed on the OSP side.
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::NetworkManager).to receive(:network_ports).and_return([])

      EmsRefresh.refresh(@ems)
      expect(CloudSubnet.count).to eq(1)
      expect(CloudNetwork.count).to eq(1)
      expect(NetworkPort.count).to eq(0)
      expect(NetworkRouter.count).to eq(1)
      expect(CloudSubnet.first.network_router_id).to be(nil)
    end

    it "shouldn't remove subnet link to router unless the interface is deleted" do
      setup_mocked_collector
      ::Settings.ems_refresh.openstack_network.allow_targeted_refresh = true

      EmsRefresh.refresh(@ems)
      expect(CloudSubnet.count).to eq(1)
      expect(CloudNetwork.count).to eq(1)
      expect(NetworkPort.count).to eq(1)
      expect(NetworkRouter.count).to eq(1)
      expect(CloudSubnet.first.network_router_id).to eq(NetworkRouter.first.id)

      target = InventoryRefresh::Target.new(
        :manager     => @ems.parent_manager,
        :association => :cloud_networks,
        :manager_ref => {
          :ems_ref => "cloud_network_1"
        }
      )
      setup_mocked_targeted_collector
      EmsRefresh.refresh(target)
      expect(CloudSubnet.count).to eq(1)
      expect(CloudNetwork.count).to eq(1)
      expect(NetworkPort.count).to eq(1)
      expect(NetworkRouter.count).to eq(1)
      expect(CloudSubnet.first.network_router_id).to eq(NetworkRouter.first.id)
      ::Settings.ems_refresh.openstack_network.allow_targeted_refresh = false
    end

    it "should update the subnet's router association correctly if the interface is simultaneously removed and replaced" do
      pending("needs a schema update to associate routers to subnets through network ports instead of directly")
      setup_mocked_collector

      EmsRefresh.refresh(@ems)
      expect(CloudSubnet.count).to eq(1)
      expect(CloudNetwork.count).to eq(1)
      expect(NetworkPort.count).to eq(1)
      expect(NetworkRouter.count).to eq(1)
      expect(CloudSubnet.first.network_router_id).to eq(NetworkRouter.first.id)

      # simulate the interface between a router and subnet being removed on the OSP side, but then recreated via a different port
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::NetworkManager).to receive(:network_ports).and_return([OpenStruct.new(
        :id              => "network_port_2",
        :name            => "network_port_2_name",
        :device_owner    => "network:router_interface",
        :device_id       => "network_router_1",
        :fixed_ips       => [{"subnet_id" => "cloud_subnet_1", "ip_address" => "10.0.0.1"}],
        :attributes      => {},
        :security_groups => [],
      )])

      EmsRefresh.refresh(@ems)
      expect(CloudSubnet.count).to eq(1)
      expect(CloudNetwork.count).to eq(1)
      expect(NetworkPort.count).to eq(1)
      expect(NetworkRouter.count).to eq(1)
      expect(CloudSubnet.first.network_router_id).to eq(NetworkRouter.first.id)
    end

    def mocked_network_ports
      [OpenStruct.new(
        :id              => "network_port_1",
        :name            => "network_port_1_name",
        :device_owner    => "network:router_interface",
        :device_id       => "network_router_1",
        :fixed_ips       => [{"subnet_id" => "cloud_subnet_1", "ip_address" => "10.0.0.1"}],
        :attributes      => {},
        :security_groups => [],
      )]
    end

    def mocked_cloud_networks
      [{
        "id"      => "cloud_network_1",
        "name"    => "cloud_network_1_name",
        "subnets" => ["cloud_subnet_1"]
      }]
    end

    def mocked_cloud_subnets
      [OpenStruct.new(
        :id         => "cloud_subnet_1",
        :name       => "cloud_subnet_1_name",
        :attributes => {},
      )]
    end

    def mocked_network_routers
      [OpenStruct.new(
        :id         => "network_router_1",
        :name       => "network_router_1_name",
        :attributes => {},
      )]
    end

    def setup_mocked_collector
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager).to receive(:availability_zones).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager).to receive(:cloud_services).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager).to receive(:vms).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager).to receive(:tenants).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager).to receive(:server_groups).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::NetworkManager).to receive(:orchestration_stacks).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::NetworkManager).to receive(:cloud_networks).and_return(mocked_cloud_networks)
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::NetworkManager).to receive(:cloud_subnets).and_return(mocked_cloud_subnets)
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::NetworkManager).to receive(:floating_ips).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::NetworkManager).to receive(:network_ports).and_return(mocked_network_ports)
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::NetworkManager).to receive(:network_routers).and_return(mocked_network_routers)
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::NetworkManager).to receive(:security_groups).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::NetworkManager).to receive(:firewall_rules).and_return([])
    end

    def setup_mocked_targeted_collector
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::TargetCollection).to receive(:availability_zones).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::TargetCollection).to receive(:cloud_services).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::TargetCollection).to receive(:vms).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::TargetCollection).to receive(:tenants).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::TargetCollection).to receive(:server_groups).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::TargetCollection).to receive(:orchestration_stacks).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::TargetCollection).to receive(:cloud_networks).and_return(mocked_cloud_networks)
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::TargetCollection).to receive(:cloud_subnets).and_return(mocked_cloud_subnets)
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::TargetCollection).to receive(:floating_ips).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::TargetCollection).to receive(:network_ports).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::TargetCollection).to receive(:network_routers).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::TargetCollection).to receive(:security_groups).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::TargetCollection).to receive(:firewall_rules).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::TargetCollection).to receive(:image_service).and_return(double(:name => "not-glance"))
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::TargetCollection).to receive(:volume_service).and_return(double(:name => "not-cinder"))
    end
  end
end

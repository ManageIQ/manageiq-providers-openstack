describe ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet do
  describe "refresh" do
    before do
      parent_ems = FactoryGirl.create(:ems_openstack_with_authentication)
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
      [OpenStruct.new(
        :id         => "cloud_network_1",
        :name       => "cloud_network_1_name",
        :attributes => {},
        :subnets    => [OpenStruct.new(
          :id         => "cloud_subnet_1",
          :name       => "cloud_subnet_1_name",
          :attributes => {}
        )],
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
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager).to receive(:vms).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager).to receive(:tenants).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::NetworkManager).to receive(:orchestration_stacks).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::NetworkManager).to receive(:cloud_networks).and_return(mocked_cloud_networks)
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::NetworkManager).to receive(:floating_ips).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::NetworkManager).to receive(:network_ports).and_return(mocked_network_ports)
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::NetworkManager).to receive(:network_routers).and_return(mocked_network_routers)
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::NetworkManager).to receive(:security_groups).and_return([])
    end
  end
end

describe ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork do
  let(:ems) { FactoryBot.create(:ems_openstack) }
  let(:tenant) { FactoryBot.create(:cloud_tenant_openstack, :ext_management_system => ems) }
  let(:ems_network) { ems.network_manager }
  let(:cloud_network) do
    FactoryBot.create(:cloud_network_openstack,
                       :ext_management_system => ems_network,
                       :name                  => 'test',
                       :ems_ref               => 'one_id',
                       :cloud_tenant          => tenant)
  end

  let(:service) do
    service = double("Fog service")
    service
  end

  let(:raw_cloud_networks) do
    raw_cloud_networks = double("cloud networks")
    allow(ExtManagementSystem).to receive(:find).with(ems_network.id).and_return(ems_network)
    allow(ems_network.parent_manager).to receive(:connect)
      .with(hash_including(:service => 'Network', :tenant_name => tenant.name)).and_return(service)
    raw_cloud_networks
  end

  let(:bad_request) do
    response = Excon::Response.new
    response.status = 400
    response.body = '{"NeutronError": {"message": "bad request"}}'
    Excon::Errors.status_error({:expects => 200}, response)
  end

  before do
    raw_cloud_networks
  end

  describe "cloud network actions" do
    context ".create" do
      it "catches errors from provider" do
        expect(service).to receive_message_chain(:networks, :new).and_raise(bad_request)
        expect do
          ems_network.create_cloud_network(:cloud_tenant => tenant)
        end.to raise_error(MiqException::MiqNetworkCreateError)
      end
    end

    context "#update_cloud_network" do
      it "updates the cloud network" do
        options = {"name" => "new-name"}

        expect(service).to receive(:update_network).with(cloud_network.ems_ref, options)
        cloud_network.update_cloud_network(options)
      end

      it "catches errors from provider" do
        expect(service).to receive(:update_network).and_raise(bad_request)
        expect { cloud_network.update_cloud_network({}) }.to raise_error(MiqException::MiqNetworkUpdateError)
      end
    end

    context "#delete_cloud_network" do
      before { NotificationType.seed }

      it "deletes the cloud network" do
        expect(service).to receive(:delete_network).with(cloud_network.ems_ref)
        cloud_network.delete_cloud_network({})
      end

      it "catches errors from provider" do
        expect(service).to receive(:delete_network).and_raise(bad_request)
        expect { cloud_network.delete_cloud_network({}) }.to raise_error(MiqException::MiqNetworkDeleteError)
      end
    end
  end
end

describe ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet do
  let(:ems) { FactoryBot.create(:ems_openstack) }
  let(:tenant) { FactoryBot.create(:cloud_tenant_openstack, :ext_management_system => ems) }
  let(:ems_network) { ems.network_manager }
  let(:cloud_network) do
    FactoryBot.create(:cloud_network_openstack,
                       :ext_management_system => ems_network,
                       :name                  => 'test_network',
                       :ems_ref               => 'network_id',
                       :cloud_tenant          => tenant)
  end

  let(:floating_ip) do
    FactoryBot.create(:floating_ip_openstack,
                       :ext_management_system => ems_network,
                       :address               => '10.10.10.10',
                       :ems_ref               => 'one_id',
                       :cloud_tenant          => tenant)
  end

  let(:service) do
    service = double("Fog service")
    service
  end

  let(:raw_floating_ips) do
    raw_floating_ips = double("floating ips")
    allow(CloudNetwork).to receive(:find).with(cloud_network.id).and_return(cloud_network)
    allow(ExtManagementSystem).to receive(:find).with(ems_network.id).and_return(ems_network)
    allow(ems_network.parent_manager).to receive(:connect)
      .with(hash_including(:service => 'Network', :tenant_name => tenant.name)).and_return(service)
    raw_floating_ips
  end

  let(:bad_request) do
    response = Excon::Response.new
    response.status = 400
    response.body = '{"NeutronError": {"message": "bad request"}}'
    Excon::Errors.status_error({:expects => 200}, response)
  end

  before do
    raw_floating_ips
  end

  describe 'floating ip actions' do
    context ".create" do
      it 'catches errors from provider' do
        expect(service).to receive(:create_floating_ip).and_raise(bad_request)
        expect do
          ems_network.create_floating_ip(:cloud_tenant => tenant, :cloud_network_id => cloud_network.id)
        end.to raise_error(MiqException::MiqFloatingIpCreateError)
      end
    end

    context "#update_floating_ip" do
      it 'catches errors from provider' do
        expect(service).to receive(:disassociate_floating_ip).and_raise(bad_request)
        expect { floating_ip.raw_update_floating_ip(:network_port_ems_ref => "") }.to raise_error(MiqException::MiqFloatingIpUpdateError)
      end
    end

    context "#delete_floating_ip" do
      it 'catches errors from provider' do
        expect(service).to receive(:delete_floating_ip).and_raise(bad_request)
        expect { floating_ip.raw_delete_floating_ip }.to raise_error(MiqException::MiqFloatingIpDeleteError)
      end
    end
  end
end

describe ManageIQ::Providers::Openstack::NetworkManager::SecurityGroup do
  let(:ems) { FactoryBot.create(:ems_openstack) }
  let(:tenant) { FactoryBot.create(:cloud_tenant_openstack, :ext_management_system => ems) }
  let(:ems_network) { ems.network_manager }
  let(:security_group) do
    FactoryBot.create(:security_group_with_firewall_rules_openstack,
                       :ext_management_system => ems_network,
                       :name                  => 'test',
                       :ems_ref               => 'one_id',
                       :cloud_tenant          => tenant)
  end

  let(:service) do
    service = double("Fog service")
    service
  end

  let(:raw_security_group) do
    raw_security_group = double("security group")
    allow(raw_security_group).to receive(:id).and_return('one_id')
    allow(raw_security_group).to receive(:status).and_return('available')
    allow(raw_security_group).to receive(:attributes).and_return({})
    raw_security_group
  end

  let(:raw_security_groups) do
    raw_security_groups = double("security groups")
    allow(ExtManagementSystem).to receive(:find).with(ems_network.id).and_return(ems_network)
    allow(ems_network.parent_manager).to receive(:connect)
      .with(hash_including(:service => 'Network', :tenant_name => tenant.name)).and_return(service)
    raw_security_groups
  end

  let(:bad_request) do
    response = Excon::Response.new
    response.status = 400
    response.body = '{"NeutronError": {"message": "bad request"}}'
    Excon::Errors.status_error({:expects => 200}, response)
  end

  before do
    raw_security_groups
  end

  describe 'security group actions' do
    context ".create" do
      let(:the_new_security_group) { {:name => "test", :description => "Test" } }
      let(:security_group_options) { {:cloud_tenant => tenant, :name => "test", :description => "Test"} }

      it 'creates a security group' do
        expect(service).to receive_message_chain(:create_security_group, :body).and_return(the_new_security_group)

        sg = ems_network.create_security_group(security_group_options)
        expect(sg.class).to         eq Hash
        expect(sg[:name]).to        eq 'test'
        expect(sg[:description]).to eq 'Test'
      end

      it "raises an error when the ems is missing" do
        expect { ems_network.create_security_group(nil) }.to raise_error(NoMethodError)
      end

      it 'catches errors from provider' do
        expect(service).to receive(:create_security_group).and_raise(bad_request)
        expect do
          ems_network.create_security_group(security_group_options)
        end.to raise_error(MiqException::MiqSecurityGroupCreateError)
      end
    end

    context "#update_security_group" do
      it 'updates the security_group' do
        security_group_options = {:description => "Test 2"}

        expect(service).to receive(:update_security_group).with(security_group[:ems_ref], security_group_options)
        security_group.raw_update_security_group(security_group_options)
      end

      it 'catches errors from provider' do
        expect(service).to receive(:update_security_group).and_raise(bad_request)
        expect { security_group.raw_update_security_group({}) }.to raise_error(MiqException::MiqSecurityGroupUpdateError)
      end

      it 'updates the security_group_rule' do
        sg_rule_options = { "host_protocol" => "TCP" }

        expect(service).to receive(:delete_security_group_rule).with("security_group_rule_id")
        expect(service).to receive(:create_security_group_rule).with(security_group.id, "egress", sg_rule_options)

        security_group.raw_delete_security_group_rule("security_group_rule_id")
        security_group.raw_create_security_group_rule(security_group.id, "outbound", sg_rule_options)
      end
    end

    context "#delete_security_group" do
      it 'deletes the security_group' do
        expect(service).to receive(:delete_security_group)
        security_group.raw_delete_security_group
      end

      it 'catches errors from provider' do
        expect(service).to receive(:delete_security_group).and_raise(bad_request)
        expect { security_group.raw_delete_security_group }.to raise_error(MiqException::MiqSecurityGroupDeleteError)
      end
    end
  end
end

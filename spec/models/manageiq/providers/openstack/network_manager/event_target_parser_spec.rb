describe ManageIQ::Providers::Openstack::NetworkManager::EventTargetParser do
  before :each do
    zone     = EvmSpecHelper.local_miq_server.zone
    @ems     = FactoryBot.create(:ems_openstack, :zone => zone)
    @manager = @ems.network_manager

    allow_any_instance_of(EmsEvent).to receive(:handle_event)
    allow(EmsEvent).to receive(:create_completed_event)
  end

  context "Openstack Event Parsing" do
    [true, false].each do |oslo_message|
      oslo_message_text = "with#{"out" unless oslo_message} oslo_message"

      it "parses network events #{oslo_message_text}" do
        payload = {
          "network" => {
            "id"         => "network_id_test",
            "name"       => "test_network",
            "tenant_id"  => "tenant_id_test",
            "project_id" => "tenant_id_test"
          }
        }
        ems_event = create_ems_event(@manager, "network.create.end", oslo_message, payload)

        parsed_targets = described_class.new(ems_event).parse
        expect(parsed_targets.size).to eq(2) # network + tenant
        expect(target_references(parsed_targets)).to(
          match_array(
            [
              [:cloud_tenants, {:ems_ref => "tenant_id_test"}],
              [:cloud_networks, {:ems_ref => "network_id_test"}]
            ]
          )
        )
      end

      it "parses subnet events #{oslo_message_text}" do
        payload = {
          "subnet" => {
            "id"         => "subnet_id_test",
            "name"       => "test_subnet",
            "tenant_id"  => "tenant_id_test",
            "project_id" => "tenant_id_test",
            "network_id" => "network_id_test"
          }
        }
        ems_event = create_ems_event(@manager, "subnet.create.end", oslo_message, payload)

        parsed_targets = described_class.new(ems_event).parse
        expect(parsed_targets.size).to eq(2) # subnet + tenant
        expect(target_references(parsed_targets)).to(
          match_array(
            [
              [:cloud_tenants, {:ems_ref => "tenant_id_test"}],
              [:cloud_subnets, {:ems_ref => "subnet_id_test"}]
            ]
          )
        )
      end

      it "parses router events #{oslo_message_text}" do
        payload = {
          "router" => {
            "id"         => "router_id_test",
            "name"       => "test_router",
            "tenant_id"  => "tenant_id_test",
            "project_id" => "tenant_id_test"
          }
        }
        ems_event = create_ems_event(@manager, "router.create.end", oslo_message, payload)

        parsed_targets = described_class.new(ems_event).parse
        expect(parsed_targets.size).to eq(2) # router + tenant
        expect(target_references(parsed_targets)).to(
          match_array(
            [
              [:cloud_tenants, {:ems_ref => "tenant_id_test"}],
              [:network_routers, {:ems_ref => "router_id_test"}]
            ]
          )
        )
      end

      it "parses port events #{oslo_message_text}" do
        payload = {
          "port" => {
            "id"         => "port_id_test",
            "name"       => "test_port",
            "tenant_id"  => "tenant_id_test",
            "project_id" => "tenant_id_test",
            "network_id" => "network_id_test"
          }
        }
        ems_event = create_ems_event(@manager, "port.create.end", oslo_message, payload)

        parsed_targets = described_class.new(ems_event).parse
        expect(parsed_targets.size).to eq(2) # port + tenant
        expect(target_references(parsed_targets)).to(
          match_array(
            [
              [:cloud_tenants, {:ems_ref => "tenant_id_test"}],
              [:network_ports, {:ems_ref => "port_id_test"}]
            ]
          )
        )
      end

      it "parses floating ip events #{oslo_message_text}" do
        payload = {
          "floatingip" => {
            "id"                  => "floating_ip_id_test",
            "floating_ip_address" => "192.168.1.100",
            "tenant_id"           => "tenant_id_test",
            "project_id"          => "tenant_id_test"
          }
        }
        ems_event = create_ems_event(@manager, "floatingip.create.end", oslo_message, payload)

        parsed_targets = described_class.new(ems_event).parse
        expect(parsed_targets.size).to eq(2) # floating_ip + tenant
        expect(target_references(parsed_targets)).to(
          match_array(
            [
              [:cloud_tenants, {:ems_ref => "tenant_id_test"}],
              [:floating_ips, {:ems_ref => "floating_ip_id_test"}]
            ]
          )
        )
      end

      it "parses security_group events #{oslo_message_text}" do
        payload = {
          "security_group" => {
            "id"         => "security_group_id_test",
            "name"       => "test_security_group",
            "tenant_id"  => "tenant_id_test",
            "project_id" => "tenant_id_test"
          }
        }
        ems_event = create_ems_event(@manager, "security_group.create.end", oslo_message, payload)

        parsed_targets = described_class.new(ems_event).parse
        expect(parsed_targets.size).to eq(2) # security_group + tenant
        expect(target_references(parsed_targets)).to(
          match_array(
            [
              [:cloud_tenants, {:ems_ref => "tenant_id_test"}],
              [:security_groups, {:ems_ref => "security_group_id_test"}]
            ]
          )
        )
      end

      it "parses security_group_rule events without ID #{oslo_message_text}" do
        payload = {
          "security_group_rule" => {
            "ethertype"         => "IPv4",
            "direction"         => "ingress",
            "security_group_id" => "security_group_id_test",
            "protocol"          => "tcp"
          }
        }
        ems_event = create_ems_event(@manager, "security_group_rule.create.end", oslo_message, payload)

        parsed_targets = described_class.new(ems_event).parse
        expect(parsed_targets.size).to eq(1) # firewall_rules with nil (full refresh)
        expect(target_references(parsed_targets)).to(
          match_array(
            [
              [:firewall_rules, {:ems_ref => nil}]
            ]
          )
        )
      end

      it "falls back to direct resource_id field when nested structure not present #{oslo_message_text}" do
        payload = {"resource_id" => "network_id_test"}
        ems_event = create_ems_event(@manager, "network.create.end", oslo_message, payload)

        parsed_targets = described_class.new(ems_event).parse
        expect(parsed_targets.size).to eq(1)
        expect(target_references(parsed_targets)).to(
          match_array(
            [
              [:cloud_networks, {:ems_ref => "network_id_test"}]
            ]
          )
        )
      end

      it "extracts tenant_id from initiator when not in resource #{oslo_message_text}" do
        payload = {
          "network" => {
            "id"   => "network_id_test",
            "name" => "test_network"
          },
          "initiator" => {
            "project_id" => "initiator_tenant_id"
          }
        }
        ems_event = create_ems_event(@manager, "network.create.end", oslo_message, payload)

        parsed_targets = described_class.new(ems_event).parse
        expect(parsed_targets.size).to eq(2)
        expect(target_references(parsed_targets)).to(
          include([:cloud_tenants, {:ems_ref => "initiator_tenant_id"}])
        )
      end
    end
  end

  def target_references(parsed_targets)
    parsed_targets.map { |x| [x.association, x.manager_ref] }.uniq
  end
end
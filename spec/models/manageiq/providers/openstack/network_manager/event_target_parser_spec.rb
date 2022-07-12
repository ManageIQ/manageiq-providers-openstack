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

      it "parses subnet events #{oslo_message_text}" do
        payload = {"resource_id" => "subnet_id_test"}
        ems_event = create_ems_event(@manager, "subnet.create.end", oslo_message, payload)

        parsed_targets = described_class.new(ems_event).parse
        expect(parsed_targets.size).to eq(1)
        expect(target_references(parsed_targets)).to(
          match_array(
            [
              [:cloud_subnets, {:ems_ref => "subnet_id_test"}]
            ]
          )
        )
      end

      it "parses router events #{oslo_message_text}" do
        payload = {"resource_id" => "router_id_test"}
        ems_event = create_ems_event(@manager, "router.create.end", oslo_message, payload)

        parsed_targets = described_class.new(ems_event).parse
        expect(parsed_targets.size).to eq(1)
        expect(target_references(parsed_targets)).to(
          match_array(
            [
              [:network_routers, {:ems_ref => "router_id_test"}]
            ]
          )
        )
      end

      it "parses port events #{oslo_message_text}" do
        payload = {"resource_id" => "port_id_test"}
        ems_event = create_ems_event(@manager, "port.create.end", oslo_message, payload)

        parsed_targets = described_class.new(ems_event).parse
        expect(parsed_targets.size).to eq(1)
        expect(target_references(parsed_targets)).to(
          match_array(
            [
              [:network_ports, {:ems_ref => "port_id_test"}]
            ]
          )
        )
      end

      it "parses floating ip events #{oslo_message_text}" do
        payload = {"resource_id" => "floating_ip_id_test"}
        ems_event = create_ems_event(@manager, "floatingip.create.end", oslo_message, payload)

        parsed_targets = described_class.new(ems_event).parse
        expect(parsed_targets.size).to eq(1)
        expect(target_references(parsed_targets)).to(
          match_array(
            [
              [:floating_ips, {:ems_ref => "floating_ip_id_test"}]
            ]
          )
        )
      end

      it "parses security_group events #{oslo_message_text}" do
        payload = {"resource_id" => "security_group_id_test"}
        ems_event = create_ems_event(@manager, "security_group.create.end", oslo_message, payload)

        parsed_targets = described_class.new(ems_event).parse
        expect(parsed_targets.size).to eq(1)
        expect(target_references(parsed_targets)).to(
          match_array(
            [
              [:security_groups, {:ems_ref => "security_group_id_test"}]
            ]
          )
        )
      end
    end
  end

  def target_references(parsed_targets)
    parsed_targets.map { |x| [x.association, x.manager_ref] }.uniq
  end
end

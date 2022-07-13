describe ManageIQ::Providers::Openstack::CloudManager::EventTargetParser do
  before :each do
    zone = EvmSpecHelper.local_miq_server.zone
    @ems                 = FactoryBot.create(:ems_openstack, :zone => zone)

    allow_any_instance_of(EmsEvent).to receive(:handle_event)
    allow(EmsEvent).to receive(:create_completed_event)
  end

  context "Openstack Event Parsing" do
    [true, false].each do |oslo_message|
      oslo_message_text = "with#{"out" unless oslo_message} oslo_message"

      it "parses compute.instance events #{oslo_message_text}" do
        payload = {
          "instance_id" => "instance_id_test",
          "tenant_id"   => "tenant_id_test"
        }
        ems_event = create_ems_event(@ems, "compute.instance.create.end", oslo_message, payload)

        parsed_targets = described_class.new(ems_event).parse
        expect(parsed_targets.size).to eq(2)
        expect(target_references(parsed_targets)).to(
          match_array(
            [
              [:vms, {:ems_ref => "instance_id_test"}],
              [:cloud_tenants, {:ems_ref => "tenant_id_test"}]
            ]
          )
        )
      end

      it "parses identity.project events #{oslo_message_text}" do
        payload = {"project_id" => "tenant_id_test"}
        ems_event = create_ems_event(@ems, "identity.project.create.end", oslo_message, payload)

        parsed_targets = described_class.new(ems_event).parse
        expect(parsed_targets.size).to eq(1)
        expect(target_references(parsed_targets)).to(
          match_array(
            [
              [:cloud_tenants, {:ems_ref => "tenant_id_test"}]
            ]
          )
        )
      end

      it "parses orchestration.stack events #{oslo_message_text}" do
        payload = {"stack_id" => "stack_id_test"}
        ems_event = create_ems_event(@ems, "orchestration.stack.create.end", oslo_message, payload)

        parsed_targets = described_class.new(ems_event).parse
        expect(parsed_targets.size).to eq(1)
        expect(target_references(parsed_targets)).to(
          match_array(
            [
              [:orchestration_stacks, {:ems_ref => "stack_id_test"}]
            ]
          )
        )
      end

      it "parses image events #{oslo_message_text}" do
        payload = {"resource_id" => "image_id_test"}
        ems_event = create_ems_event(@ems, "image.create.end", oslo_message, payload)

        parsed_targets = described_class.new(ems_event).parse
        expect(parsed_targets.size).to eq(2)
        expect(target_references(parsed_targets)).to(
          match_array(
            [
              [:images, {:ems_ref=>"image_id_test"}], [:miq_templates, {:ems_ref=>"image_id_test"}]
            ]
          )
        )
      end

      it "parses host aggregate events #{oslo_message_text}" do
        payload = {"service" => "aggregate.id_test"}
        ems_event = create_ems_event(@ems, "aggregate.create.end", oslo_message, payload)

        parsed_targets = described_class.new(ems_event).parse
        expect(parsed_targets.size).to eq(1)
        expect(target_references(parsed_targets)).to(
          match_array(
            [
              [:host_aggregates, {:ems_ref => "id_test"}]
            ]
          )
        )
      end

      it "doesn't create duplicate events #{oslo_message_text}" do
        payload = {"service" => "compute"}
        create_ems_event(@ems, "compute.instance.create.start", oslo_message, payload)
        # these two should have identical timestamps, event_types, and ems_ids,
        # so they are probably duplicate events. As such, only one EmsEvent
        # should be created.
        create_ems_event(@ems, "compute.instance.create.end", oslo_message, payload)
        create_ems_event(@ems, "compute.instance.create.end", oslo_message, payload)
        expect(EmsEvent.all.count).to eq(2)
      end
    end
  end

  def target_references(parsed_targets)
    parsed_targets.map { |x| [x.association, x.manager_ref] }.uniq
  end
end

describe ManageIQ::Providers::Openstack::InfraManager::RefreshWorker do
  context "EMS with children" do
    let!(:network_manager) { FactoryBot.create(:ems_network) }
    let!(:storage_manager) { FactoryBot.create(:ems_storage) }
    let(:ems) do
      FactoryBot.create(:ems_infra).tap do |ems|
        network_manager.update(:parent_ems_id => ems.id)
        storage_manager.update(:parent_ems_id => ems.id)
      end
    end

    it ".queue_name_for_ems" do
      queue_name = described_class.queue_name_for_ems(ems)
      expect(queue_name.count).to eq(3)
      expect(queue_name.sort).to  eq(queue_name)
    end
  end

  context "EMS with no children" do
    let(:ems) { FactoryBot.create(:ems_infra) }

    it ".queue_name_for_ems" do
      queue_name = described_class.queue_name_for_ems(ems)
      expect(queue_name).to eq(ems.queue_name)
    end
  end
end

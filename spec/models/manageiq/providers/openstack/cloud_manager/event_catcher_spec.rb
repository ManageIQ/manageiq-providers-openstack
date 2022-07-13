describe ManageIQ::Providers::Openstack::CloudManager::EventCatcher do
  before do
    zone = EvmSpecHelper.local_miq_server.zone
    @ems = FactoryBot.create(:ems_openstack, :with_authentication, :zone => zone, :capabilities => {"events" => events_supported})
    allow(ManageIQ::Providers::Openstack::CloudManager::EventCatcher).to receive(:all_ems_in_zone).and_return([@ems])
  end

  context "when EMS does not have Event Monitors available" do
    let(:events_supported) { false }

    it "doesn't include ems in all_valid_ems_in_zone" do
      expect(ManageIQ::Providers::Openstack::CloudManager::EventCatcher.all_valid_ems_in_zone).not_to include(@ems)
    end
  end

  context "when EMS can provide an event monitor" do
    let(:events_supported) { true }

    it "includes ems in all_valid_ems_in_zone" do
      expect(ManageIQ::Providers::Openstack::CloudManager::EventCatcher.all_valid_ems_in_zone).to include(@ems)
    end
  end
end

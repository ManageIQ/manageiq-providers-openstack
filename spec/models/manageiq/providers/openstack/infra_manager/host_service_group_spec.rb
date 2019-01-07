describe ManageIQ::Providers::Openstack::InfraManager::HostServiceGroup do
  let(:host_service_group) { FactoryBot.create(:host_service_group_openstack) }

  describe "return scopes" do
    it "calls Filesystem scope" do
      expect(Filesystem).to receive(:host_service_group_filesystems).with(host_service_group.id)
      host_service_group.host_service_group_filesystems
    end

    it "calls SystemService scope with running systemd" do
      expect(SystemService).to receive(:host_service_group_running_systemd).with(host_service_group.id)
      host_service_group.running_system_services
    end

    it "calls SystemService scope with failed systemd" do
      expect(SystemService).to receive(:host_service_group_failed_systemd).with(host_service_group.id)
      host_service_group.failed_system_services
    end
  end
end

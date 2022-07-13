describe ManageIQ::Providers::Openstack::CloudManager::Refresher do
  before(:each) do
    EmsRefresh.debug_failures = false

    zone = EvmSpecHelper.local_miq_server.zone
    @ems = FactoryBot.create(
      :ems_openstack,
      :zone      => zone,
      :hostname  => "1.2.3.4",
      :ipaddress => "1.2.3.4",
      :port      => 5000)
    @ems.update_authentication(:default => {:userid => "admin", :password => "password"})
  end

  it "will record an error when trying to perform a full refresh against RHOS Havana" do
    error = "Bad Request"
    refresh_ems(@ems, error)
    assert_failed_refresh(error)
  end

  def assert_failed_refresh(error)
    expect(@ems.last_refresh_status).to eq("error")
    expect(@ems.last_refresh_error).to eq(error)
  end

  def refresh_ems(ems, error)
    allow_any_instance_of(ManageIQ::Providers::Openstack::CloudManager::Refresher)
      .to receive(:refresh_targets_for_ems).and_raise(Excon::Errors::BadRequest.new(error))
    expect do
      EmsRefresh.refresh(ems)
    end.to raise_error(@ems.refresher::PartialRefreshError)
  end
end

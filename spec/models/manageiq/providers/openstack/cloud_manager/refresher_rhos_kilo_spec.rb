require_relative "refresh_spec_common"

describe ManageIQ::Providers::Openstack::CloudManager::Refresher do
  include Openstack::RefreshSpecCommon

  before(:each) do
    setup_ems('11.22.33.44', 'password_2WpEraURh')
    @environment = :kilo
  end

  it "will perform a full refresh against RHOS #{@environment}" do
    2.times do # Run twice to verify that a second run with existing data does not change anything
      with_cassette(@environment, @ems) do
        EmsRefresh.refresh(@ems)
        EmsRefresh.refresh(@ems.network_manager)
        EmsRefresh.refresh(@ems.cinder_manager)
        EmsRefresh.refresh(@ems.swift_manager)
      end

      assert_common
    end
  end

  context "when configured with skips" do

    it "will not parse the ignored items" do
      with_cassette(@environment, @ems) do
        EmsRefresh.refresh(@ems)
        EmsRefresh.refresh(@ems.network_manager)
        EmsRefresh.refresh(@ems.cinder_manager)
        EmsRefresh.refresh(@ems.swift_manager)
      end

      assert_with_skips
    end
  end

  context "when random 403 and 404 errors occurs" do
    it "refresh will continue" do
      stub_excon_errors

      with_cassette('kilo_with_errors', @ems) do
        EmsRefresh.refresh(@ems)
        EmsRefresh.refresh(@ems.network_manager)
        EmsRefresh.refresh(@ems.cinder_manager)
        EmsRefresh.refresh(@ems.swift_manager)
      end

      assert_with_errors
    end
  end

  context "when using an admin account for fast refresh" do
    it "will perform a fast full refresh against RHOS #{@environment}" do
      ::Settings.ems_refresh.openstack.is_admin = true
      ::Settings.ems_refresh.openstack_network.is_admin = true
      2.times do
        with_cassette("#{@environment}_fast_refresh", @ems) do
          EmsRefresh.refresh(@ems)
          EmsRefresh.refresh(@ems.network_manager)
          EmsRefresh.refresh(@ems.cinder_manager)
          EmsRefresh.refresh(@ems.swift_manager)
        end

        assert_common
      end
      ::Settings.ems_refresh.openstack.is_admin = false
      ::Settings.ems_refresh.openstack_network.is_admin = false
    end
  end

  it "will perform a fast full legacy refresh against RHOS #{@environment}" do
    ::Settings.ems_refresh.openstack.is_admin = true
    ::Settings.ems_refresh.openstack_network.is_admin = true
    ::Settings.ems_refresh.openstack.inventory_object_refresh = false
    ::Settings.ems_refresh.openstack_network.inventory_object_refresh = false
    2.times do
      with_cassette("#{@environment}_legacy_fast_refresh", @ems) do
        EmsRefresh.refresh(@ems)
        EmsRefresh.refresh(@ems.network_manager)
        EmsRefresh.refresh(@ems.cinder_manager)
        EmsRefresh.refresh(@ems.swift_manager)
      end

      assert_common
    end
    ::Settings.ems_refresh.openstack.is_admin = false
    ::Settings.ems_refresh.openstack_network.is_admin = false
    ::Settings.ems_refresh.openstack.inventory_object_refresh = true
    ::Settings.ems_refresh.openstack_network.inventory_object_refresh = true
  end
end

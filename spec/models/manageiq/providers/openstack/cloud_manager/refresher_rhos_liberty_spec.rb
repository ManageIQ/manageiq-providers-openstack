require_relative "refresh_spec_common"

describe ManageIQ::Providers::Openstack::CloudManager::Refresher do
  include Openstack::RefreshSpecCommon

  before(:each) do
    setup_ems('11.22.33.44', 'password_2WpEraURh')
    @environment = :liberty
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
    ::Settings.ems_refresh.cinder.inventory_object_refresh = false

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
    ::Settings.ems_refresh.cinder.inventory_object_refresh = true
  end

  context "targeted refresh" do
    it "will perform a targeted VM refresh against RHOS #{@environment}" do
      # EmsRefreshSpec-PoweredOn
      vm_target = InventoryRefresh::Target.new(:manager => @ems, :association => :vms, :manager_ref => {:ems_ref => "8daeb8f2-3779-4331-a876-3806676f1fe1"})
      # Run twice to verify that a second run with existing data does not change anything.
      with_cassette("#{@environment}_vm_targeted_refresh", @ems) do
        EmsRefresh.refresh(vm_target)
        assert_targeted_vm("EmsRefreshSpec-PoweredOn", :power_state => "on",)
        EmsRefresh.refresh(vm_target)
        assert_targeted_vm("EmsRefreshSpec-PoweredOn", :power_state => "on",)
      end
    end

    it "will perform a targeted stack refresh against RHOS #{@environment}" do
      # stack1
      stack_target = InventoryRefresh::Target.new(:manager     => @ems,
                                                :association => :orchestration_stacks,
                                                :manager_ref => {:ems_ref => "eca4b0d4-c342-4b89-94bb-fe66f001460b"},
                                                :options     => {:tenant_id => "8eb4b49207904f6eb33283732571bc0e"})
      2.times do # Run twice to verify that a second run with existing data does not change anything
        with_cassette("#{@environment}_stack_targeted_refresh", @ems) do
          EmsRefresh.refresh(stack_target)
          assert_targeted_stack
        end
      end
    end

    it "will perform a targeted tenant refresh against RHOS #{@environment}" do
      # EmsRefreshSpec-Project
      stack_target = InventoryRefresh::Target.new(:manager     => @ems,
                                                :association => :cloud_tenants,
                                                :manager_ref => {:ems_ref => "8eb4b49207904f6eb33283732571bc0e"})
      2.times do # Run twice to verify that a second run with existing data does not change anything
        with_cassette("#{@environment}_tenant_targeted_refresh", @ems) do
          EmsRefresh.refresh(stack_target)
          expect(CloudTenant.count).to eq(1)
          assert_targeted_tenant
        end
      end
    end

    it "will perform a targeted router refresh against RHOS #{@environment}" do
      router_target = InventoryRefresh::Target.new(:manager     => @ems,
                                                 :association => :network_routers,
                                                 :manager_ref => {:ems_ref => "cdbbd8a3-7ba1-4264-88a7-a1279558f77f"})

      2.times do # Run twice to verify that a second run with existing data does not change anything
        with_cassette("#{@environment}_router_targeted_refresh", @ems) do
          EmsRefresh.refresh(router_target)
          expect(NetworkRouter.count).to eq(1)
          router = NetworkRouter.find_by(:ems_ref => "cdbbd8a3-7ba1-4264-88a7-a1279558f77f")
          expect(router.ext_management_system).to eq(@ems.network_manager)
        end
      end
    end

    # attached to 0c338e1b-b23c-41e8-8223-fc8086d24e96
    it "will perform a targeted volume refresh against RHOS #{@environment}" do
      volume_target = InventoryRefresh::Target.new(:manager     => @ems,
                                                   :association => :cloud_volumes,
                                                   :manager_ref => {:ems_ref => "2042bbec-e245-405e-8e77-cde0205ab38e"})

      2.times do # Run twice to verify that a second run with existing data does not change anything
        with_cassette("#{@environment}_volume_targeted_refresh", @ems) do
          EmsRefresh.refresh(volume_target)
          expect(CloudVolume.count).to eq(1)
          volume = CloudVolume.find_by(:ems_ref => "2042bbec-e245-405e-8e77-cde0205ab38e")
          expect(volume.ext_management_system).to eq(@ems.cinder_manager)
          expect(VmCloud.count).to eq(1)
          vm = VmCloud.find_by(:ems_ref => "0c338e1b-b23c-41e8-8223-fc8086d24e96")
          expect(vm.ext_management_system).to eq(@ems)
          expect(volume.vms.include?(vm)).to be true
        end
      end
    end

    it "will perform a targeted port refresh against RHOS #{@environment}" do
      port_target = InventoryRefresh::Target.new(:manager     => @ems,
                                               :association => :network_ports,
                                               :manager_ref => {:ems_ref => "0134788e-bb49-4327-8f26-5584d4426305"})

      2.times do # Run twice to verify that a second run with existing data does not change anything
        with_cassette("#{@environment}_port_targeted_refresh", @ems) do
          EmsRefresh.refresh(port_target)
          expect(NetworkPort.count).to eq(1)
          router = NetworkPort.find_by(:ems_ref => "0134788e-bb49-4327-8f26-5584d4426305")
          expect(router.ext_management_system).to eq(@ems.network_manager)
        end
      end
    end

    it "will not wipe out subnet relationships when performing a targeted network refresh against RHOS #{@environment}" do
      with_cassette("#{@environment}_network_targeted_refresh", @ems) do
        EmsRefresh.refresh(@ems)
        EmsRefresh.refresh(@ems.network_manager)
        EmsRefresh.refresh(@ems.cinder_manager)
        EmsRefresh.refresh(@ems.swift_manager)

        @ems.cloud_subnets.each do |subnet|
          expect(subnet.cloud_network_id).to_not be(nil)
        end

        network = CloudNetwork.find_by(:name => "EmsRefreshSpec-NetworkPublic")
        network_target = InventoryRefresh::Target.new(:manager     => @ems,
                                                    :association => :cloud_networks,
                                                    :manager_ref => {:ems_ref => network.ems_ref})
        EmsRefresh.refresh(network_target)
        @ems.cloud_subnets.each do |subnet|
          expect(subnet.cloud_network_id).to_not be(nil)
        end
      end
    end

    # BZ 1662126
    it "will reset the cache before collecting tenants during targeted refresh against RHOS #{@environment}" do
      volume_target = InventoryRefresh::Target.new(:manager     => @ems,
                                                   :association => :cloud_volumes,
                                                   :manager_ref => {:ems_ref => "2042bbec-e245-405e-8e77-cde0205ab38e"})
      tenant_target = InventoryRefresh::Target.new(:manager     => @ems,
                                                   :association => :cloud_tenants,
                                                   :manager_ref => {:ems_ref => "66df12d5801449a2b529d3a1bbf279b0"})

      2.times do # Run twice to verify that a second run with existing data does not change anything
        with_cassette("#{@environment}_volume_targeted_refresh", @ems) do
          EmsRefresh.refresh([tenant_target, volume_target])
          expect(CloudVolume.count).to eq(1)
          volume = CloudVolume.find_by(:ems_ref => "2042bbec-e245-405e-8e77-cde0205ab38e")
          expect(CloudTenant.all.count).to eq(2)
          expect(CloudTenant.find_by(:ems_ref => "8eb4b49207904f6eb33283732571bc0e")).to be_truthy
          expect(CloudTenant.find_by(:ems_ref => "66df12d5801449a2b529d3a1bbf279b0")).to be_truthy
        end
      end
    end
  end
end

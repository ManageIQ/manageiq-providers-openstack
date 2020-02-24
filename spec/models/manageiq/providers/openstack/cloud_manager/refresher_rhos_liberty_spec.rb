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

  context "targeted refresh" do
    it "will perform a targeted VM refresh against RHOS #{@environment}" do
      # EmsRefreshSpec-PoweredOn
      vm_target = InventoryRefresh::Target.new(:manager => @ems, :association => :vms, :manager_ref => {:ems_ref => "da40eae5-9021-4406-939e-d9dd9b528f3d"})
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
                                                :manager_ref => {:ems_ref => "a2865569-94f8-42d0-84c3-4b59dd4dc745"},
                                                :options     => {:tenant_id => "e9bb9a5ed00244e0b3c288ed495abbf9"})
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
                                                :manager_ref => {:ems_ref => "e9bb9a5ed00244e0b3c288ed495abbf9"})
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
                                                 :manager_ref => {:ems_ref => "f549eb23-42ae-4983-8ffd-2464b9997302"})

      2.times do # Run twice to verify that a second run with existing data does not change anything
        with_cassette("#{@environment}_router_targeted_refresh", @ems) do
          EmsRefresh.refresh(router_target)
          expect(NetworkRouter.count).to eq(1)
          router = NetworkRouter.find_by(:ems_ref => "f549eb23-42ae-4983-8ffd-2464b9997302")
          expect(router.ext_management_system).to eq(@ems.network_manager)
        end
      end
    end

    # attached to 2c17e2a5-bc80-48a3-bd46-d2e6b258cac0
    it "will perform a targeted volume refresh against RHOS #{@environment}" do
      volume_target = InventoryRefresh::Target.new(:manager     => @ems,
                                                   :association => :cloud_volumes,
                                                   :manager_ref => {:ems_ref => "12a60717-cc9e-426d-82d6-7ac2e8eabd3a"})

      2.times do # Run twice to verify that a second run with existing data does not change anything
        with_cassette("#{@environment}_volume_targeted_refresh", @ems) do
          EmsRefresh.refresh(volume_target)
          expect(CloudVolume.count).to eq(1)
          volume = CloudVolume.find_by(:ems_ref => "12a60717-cc9e-426d-82d6-7ac2e8eabd3a")
          expect(volume.ext_management_system).to eq(@ems.cinder_manager)
          expect(VmCloud.count).to eq(1)
          vm = VmCloud.find_by(:ems_ref => "2c17e2a5-bc80-48a3-bd46-d2e6b258cac0")
          expect(vm.ext_management_system).to eq(@ems)
          expect(volume.vms.include?(vm)).to be true
        end
      end
    end

    it "will perform a targeted port refresh against RHOS #{@environment}" do
      port_target = InventoryRefresh::Target.new(:manager     => @ems,
                                               :association => :network_ports,
                                               :manager_ref => {:ems_ref => "04439a32-2c8b-495d-8ca2-aabfffca56ba"})

      2.times do # Run twice to verify that a second run with existing data does not change anything
        with_cassette("#{@environment}_port_targeted_refresh", @ems) do
          EmsRefresh.refresh(port_target)
          expect(NetworkPort.count).to eq(1)
          router = NetworkPort.find_by(:ems_ref => "04439a32-2c8b-495d-8ca2-aabfffca56ba")
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
                                                   :manager_ref => {:ems_ref => "12a60717-cc9e-426d-82d6-7ac2e8eabd3a"})
      tenant_target = InventoryRefresh::Target.new(:manager     => @ems,
                                                   :association => :cloud_tenants,
                                                   :manager_ref => {:ems_ref => "4f018636e6414466b02641748cd91484"})

      2.times do # Run twice to verify that a second run with existing data does not change anything
        with_cassette("#{@environment}_volume_targeted_refresh", @ems) do
          EmsRefresh.refresh([tenant_target, volume_target])
          expect(CloudVolume.count).to eq(1)
          volume = CloudVolume.find_by(:ems_ref => "12a60717-cc9e-426d-82d6-7ac2e8eabd3a")
          expect(CloudTenant.all.count).to eq(2)
          expect(CloudTenant.find_by(:ems_ref => "e9bb9a5ed00244e0b3c288ed495abbf9")).to be_truthy
          expect(CloudTenant.find_by(:ems_ref => "4f018636e6414466b02641748cd91484")).to be_truthy
        end
      end
    end
  end
end

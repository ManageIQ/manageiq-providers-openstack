describe ManageIQ::Providers::Openstack::CloudManager::ProvisionWorkflow do
  include Spec::Support::WorkflowHelper

  let(:admin)    { FactoryBot.create(:user_with_group) }
  let(:provider) do
    allow_any_instance_of(User).to receive(:get_timezone).and_return(Time.zone)
    FactoryBot.create(:ems_openstack)
  end

  let(:template) { FactoryBot.create(:template_openstack, :ext_management_system => provider) }

  context "without applied tags" do
    let(:workflow) do
      stub_dialog
      allow_any_instance_of(described_class).to receive(:update_field_visibility)
      described_class.new({:src_vm_id => template.id}, admin.userid)
    end
    context "availability_zones" do
      it "#get_targets_for_ems" do
        az = FactoryBot.create(:availability_zone_amazon)
        provider.availability_zones << az
        filtered = workflow.send(:get_targets_for_ems, provider, :cloud_filter, AvailabilityZone,
                                 'availability_zones.available')
        expect(filtered.size).to eq(1)
        expect(filtered.first.name).to eq(az.name)
      end

      it "returns an empty array when no targets are found" do
        filtered = workflow.send(:get_targets_for_ems, provider, :cloud_filter, AvailabilityZone,
                                 'availability_zones.available')
        expect(filtered).to eq([])
      end
    end

    context "security_groups" do
      context "non cloud network" do
        it "#get_targets_for_ems" do
          sg = FactoryBot.create(:security_group_openstack, :ext_management_system => provider.network_manager)
          filtered = workflow.send(:get_targets_for_ems, provider, :cloud_filter, SecurityGroup,
                                   'security_groups.non_cloud_network')
          expect(filtered.size).to eq(1)
          expect(filtered.first.name).to eq(sg.name)
        end
      end

      context "cloud network" do
        it "#get_targets_for_ems" do
          cn1 = FactoryBot.create(:cloud_network, :ext_management_system => provider.network_manager)
          sg_cn = FactoryBot.create(:security_group_openstack, :ext_management_system => provider.network_manager, :cloud_network => cn1)
          filtered = workflow.send(:get_targets_for_ems, provider, :cloud_filter, SecurityGroup, 'security_groups')
          expect(filtered.size).to eq(1)
          expect(filtered.first.name).to eq(sg_cn.name)
        end
      end
    end

    context "Instance Type (Flavor)" do
      it "#get_targets_for_ems" do
        flavor = FactoryBot.create(:flavor_openstack)
        provider.flavors << flavor
        filtered = workflow.send(:get_targets_for_ems, provider, :cloud_filter, Flavor, 'flavors')
        expect(filtered.size).to eq(1)
        expect(filtered.first.name).to eq(flavor.name)
      end
    end
  end

  context "with applied tags" do
    let(:workflow) do
      stub_dialog
      allow_any_instance_of(described_class).to receive(:update_field_visibility)
      described_class.new({:src_vm_id => template.id}, admin.userid)
    end

    before do
      FactoryBot.create(:classification_cost_center_with_tags)
      admin.current_group.entitlement = Entitlement.create!
      admin.current_group.entitlement.set_managed_filters([['/managed/cc/001']])
      admin.current_group.save!

      2.times { FactoryBot.create(:availability_zone_amazon, :ems_id => provider.id) }
      2.times { FactoryBot.create(:security_group_openstack, :ext_management_system => provider.network_manager) }
      ct1 = FactoryBot.create(:cloud_tenant)
      ct2 = FactoryBot.create(:cloud_tenant)
      provider.cloud_tenants << ct1
      provider.cloud_tenants << ct2
      provider.flavors << FactoryBot.create(:flavor_openstack)
      provider.flavors << FactoryBot.create(:flavor_openstack)

      tagged_zone = provider.availability_zones.first
      tagged_sec = provider.security_groups.first
      tagged_flavor = provider.flavors.first
      tagged_tenant = provider.cloud_tenants.first
      Classification.classify(tagged_zone, 'cc', '001')
      Classification.classify(tagged_sec, 'cc', '001')
      Classification.classify(tagged_flavor, 'cc', '001')
      Classification.classify(tagged_tenant, 'cc', '001')
    end

    context "availability_zones" do
      it "#get_targets_for_ems" do
        expect(provider.availability_zones.size).to eq(2)
        expect(provider.availability_zones.first.tags.size).to eq(1)
        expect(provider.availability_zones.last.tags.size).to eq(0)

        filtered = workflow.send(:get_targets_for_ems, provider, :cloud_filter, AvailabilityZone,
                                 'availability_zones.available')
        expect(filtered.size).to eq(1)
      end
    end

    context "security groups" do
      it "#get_targets_for_ems" do
        expect(provider.security_groups.size).to eq(2)
        expect(provider.security_groups.first.tags.size).to eq(1)
        expect(provider.security_groups.last.tags.size).to eq(0)

        expect(workflow.send(:get_targets_for_ems,
                             provider,
                             :cloud_filter,
                             SecurityGroup,
                             'security_groups').size)
          .to eq(1)
      end
    end

    context "instance types (Flavor)" do
      it "#get_targets_for_ems" do
        expect(provider.flavors.size).to eq(2)
        expect(provider.flavors.first.tags.size).to eq(1)
        expect(provider.flavors.last.tags.size).to eq(0)

        expect(workflow.send(:get_targets_for_ems, provider, :cloud_filter, Flavor, 'flavors').size).to eq(1)
      end
    end

    context "allowed_tenants" do
      it "#get_targets_for_ems" do
        expect(provider.cloud_tenants.size).to eq(2)
        expect(provider.cloud_tenants.first.tags.size).to eq(1)
        expect(provider.cloud_tenants.last.tags.size).to eq(0)

        expect(workflow.send(:get_targets_for_ems, provider, :cloud_filter, CloudTenant, 'cloud_tenants').size).to eq(1)
      end
    end
  end

  context "With a user" do
    it "pass platform attributes to automate" do
      stub_dialog
      assert_automate_dialog_lookup(admin, 'cloud', 'openstack')

      described_class.new({}, admin.userid)
    end

    context "Without a Template" do
      let(:workflow) do
        stub_dialog
        allow_any_instance_of(described_class).to receive(:update_field_visibility)
        described_class.new({}, admin.userid)
      end

      it "#allowed_instance_types" do
        provider.flavors << FactoryBot.create(:flavor_openstack)

        expect(workflow.allowed_instance_types).to eq({})
      end
    end

    context "With a Valid Template" do
      let(:workflow) do
        stub_dialog
        allow_any_instance_of(described_class).to receive(:update_field_visibility)
        described_class.new({:src_vm_id => template.id}, admin.userid)
      end

      context "#allowed_instance_types" do
        let(:template) { FactoryBot.create(:template_openstack, :hardware => hardware, :ext_management_system => provider) }

        context "with regular hardware" do
          let(:hardware) { FactoryBot.create(:hardware, :size_on_disk => 1.gigabyte, :memory_mb_minimum => 512) }

          it "filters flavors too small" do
            flavor = FactoryBot.create(:flavor_openstack, :memory => 1.gigabyte, :root_disk_size => 1.terabyte)
            provider.flavors << flavor
            provider.flavors << FactoryBot.create(:flavor_openstack, :memory => 1.gigabyte, :root_disk_size => 1.megabyte) # Disk too small
            provider.flavors << FactoryBot.create(:flavor_openstack, :memory => 1.megabyte, :root_disk_size => 1.terabyte) # Memory too small

            ram = ActionController::Base.helpers.number_to_human_size(flavor.memory)
            disk_size = ActionController::Base.helpers.number_to_human_size(flavor.root_disk_size)
            descr = "#{flavor.cpus} CPUs, #{ram} RAM, #{disk_size} Root Disk"

            expect(workflow.allowed_instance_types).to eq(flavor.id => "#{flavor.name}: #{descr}")
          end
        end

        context "hardware with no size_on_disk" do
          let(:hardware) { FactoryBot.create(:hardware, :memory_mb_minimum => 512) }

          it "filters flavors too small" do
            flavor = FactoryBot.create(:flavor_openstack, :memory => 1.gigabyte, :root_disk_size => 1.terabyte)
            provider.flavors << flavor
            provider.flavors << FactoryBot.create(:flavor_openstack, :memory => 1.megabyte, :root_disk_size => 1.terabyte) # Memory too small

            ram = ActionController::Base.helpers.number_to_human_size(flavor.memory)
            disk_size = ActionController::Base.helpers.number_to_human_size(flavor.root_disk_size)
            descr = "#{flavor.cpus} CPUs, #{ram} RAM, #{disk_size} Root Disk"

            expect(workflow.allowed_instance_types).to eq(flavor.id => "#{flavor.name}: #{descr}")
          end
        end
      end

      context "with empty relationships" do
        it "#allowed_availability_zones" do
          expect(workflow.allowed_availability_zones).to eq({})
        end

        it "#allowed_guest_access_key_pairs" do
          expect(workflow.allowed_guest_access_key_pairs).to eq({})
        end

        it "#allowed_security_groups" do
          expect(workflow.allowed_security_groups).to eq({})
        end
      end

      context "with valid relationships" do
        it "#allowed_availability_zones" do
          az = FactoryBot.create(:availability_zone_openstack)
          az.provider_services_supported = ["compute"]
          excluded_az = FactoryBot.create(:availability_zone_openstack)
          excluded_az.provider_services_supported = ["volume"]
          provider.availability_zones << az
          expect(workflow.allowed_availability_zones).to eq(az.id => az.name)
        end

        it "#allowed_availability_zones with NULL AZ" do
          az = FactoryBot.create(:availability_zone_openstack)
          az.provider_services_supported = ["compute"]
          provider.availability_zones << az
          provider.availability_zones << FactoryBot.create(:availability_zone_openstack_null, :ems_ref => "null_az")

          azs = workflow.allowed_availability_zones
          expect(azs.length).to eq(1)
          expect(azs.first).to eq([az.id, az.name])
        end

        it "#allowed_guest_access_key_pairs" do
          kp = ManageIQ::Providers::Openstack::CloudManager::AuthKeyPair.create(:name => "auth_1")
          provider.key_pairs << kp
          expect(workflow.allowed_guest_access_key_pairs).to eq(kp.id => kp.name)
        end

        it "#allowed_security_groups" do
          sg = FactoryBot.create(:security_group_openstack)
          provider.security_groups << sg
          expect(workflow.allowed_security_groups).to eq(sg.id => sg.name)
        end
      end

      context "availability_zone_to_cloud_network" do
        it "has one when it should" do
          subnet = FactoryBot.create(:cloud_subnet_openstack)
          FactoryBot.create(:cloud_network_openstack, :ext_management_system => provider.network_manager, :cloud_subnets => [subnet])

          expect(workflow.allowed_cloud_networks.size).to eq(1)
        end

        it "filters cloud networks without subnets" do
          FactoryBot.create(:cloud_network_openstack, :ext_management_system => provider.network_manager)

          expect(workflow.allowed_cloud_networks.size).to eq(0)
        end

        it "has none when it should" do
          expect(workflow.allowed_cloud_networks.size).to eq(0)
        end
      end

      context "#display_name_for_name_description" do
        let(:flavor) { FactoryBot.create(:flavor_openstack) }

        it "with name and description" do
          ram = ActionController::Base.helpers.number_to_human_size(flavor.memory)
          disk_size = ActionController::Base.helpers.number_to_human_size(flavor.root_disk_size)
          descr = "#{flavor.cpus} CPUs, #{ram} RAM, #{disk_size} Root Disk"
          expect(workflow.display_name_for_name_description(flavor)).to eq("#{flavor.name}: #{descr}")
        end
      end

      context "tenant filtering" do
        before do
          @ct1 = FactoryBot.create(:cloud_tenant_openstack)
          @ct2 = FactoryBot.create(:cloud_tenant_openstack)
          provider.cloud_tenants << @ct1
          provider.cloud_tenants << @ct2
        end

        context "cloud networks" do
          before do
            subnet1 = FactoryBot.create(:cloud_subnet_openstack)
            subnet2 = FactoryBot.create(:cloud_subnet_openstack)
            subnet3 = FactoryBot.create(:cloud_subnet_openstack)
            subnet4 = FactoryBot.create(:cloud_subnet_openstack)
            subnet5 = FactoryBot.create(:cloud_subnet_openstack)
            @cn1 = FactoryBot.create(:cloud_network_private_openstack,
                                      :cloud_tenant          => @ct1,
                                      :ext_management_system => provider.network_manager,
                                      :cloud_subnets         => [subnet1])
            @cn2 = FactoryBot.create(:cloud_network_private_openstack,
                                      :cloud_tenant          => @ct2,
                                      :ext_management_system => provider.network_manager,
                                      :cloud_subnets         => [subnet2])
            @cn3 = FactoryBot.create(:cloud_network_public_openstack,
                                      :cloud_tenant          => @ct2,
                                      :ext_management_system => provider.network_manager,
                                      :cloud_subnets         => [subnet3])

            @cn_shared        = FactoryBot.create(:cloud_network_private_openstack,
                                                   :shared                => true,
                                                   :cloud_tenant          => @ct2,
                                                   :ext_management_system => provider.network_manager,
                                                   :cloud_subnets         => [subnet4])
            @cn_public_shared = FactoryBot.create(:cloud_network_public_openstack,
                                                   :shared                => true,
                                                   :cloud_tenant          => @ct2,
                                                   :ext_management_system => provider.network_manager,
                                                   :cloud_subnets         => [subnet5])
          end

          it "#allowed_cloud_networks with tenant selected" do
            workflow.values.merge!(:cloud_tenant => @ct2.id)
            cns = workflow.allowed_cloud_networks
            expect(cns.keys).to match_array [@cn2.id, @cn3.id, @cn_shared.id, @cn_public_shared.id]
          end

          it "#allowed_cloud_networks with another tenant selected" do
            workflow.values[:cloud_tenant] = @ct1.id
            cns = workflow.allowed_cloud_networks
            expect(cns.keys).to match_array [@cn1.id, @cn_shared.id, @cn_public_shared.id]
          end

          it "#allowed_cloud_networks with tenant not selected" do
            cns = workflow.allowed_cloud_networks
            expect(cns.keys).to match_array [@cn2.id, @cn3.id, @cn1.id, @cn_shared.id, @cn_public_shared.id]
          end
        end

        context "security groups" do
          before do
            @sg1 = FactoryBot.create(:security_group_openstack)
            @sg2 = FactoryBot.create(:security_group_openstack)
            provider.network_manager.security_groups << @sg1
            provider.network_manager.security_groups << @sg2
            @ct1.security_groups << @sg1
            @ct2.security_groups << @sg2
          end

          it "#allowed_security_groups with tenant selected" do
            workflow.values.merge!(:cloud_tenant => @ct2.id)
            sgs = workflow.allowed_security_groups
            expect(sgs.keys).to match_array [@sg2.id]
          end

          it "#allowed_security_groups with tenant not selected" do
            sgs = workflow.allowed_security_groups
            expect(sgs.keys).to match_array [@sg2.id, @sg1.id]
          end
        end

        context "floating ip" do
          before do
            cloud_network_public   = FactoryBot.create(:cloud_network_public_openstack)
            cloud_network_public_2 = FactoryBot.create(:cloud_network_public_openstack)
            router                 = FactoryBot.create(:network_router_openstack,
                                                        :cloud_network => cloud_network_public)
            @cloud_network         = FactoryBot.create(:cloud_network_private_openstack,
                                                        :cloud_tenant => @ct2)
            @cloud_network_2       = FactoryBot.create(:cloud_network_private_openstack,
                                                        :cloud_tenant => @ct2)
            _subnet                = FactoryBot.create(:cloud_subnet_openstack,
                                                        :network_router        => router,
                                                        :cloud_network         => @cloud_network,
                                                        :ext_management_system => provider.network_manager)

            @ip1 = FactoryBot.create(:floating_ip,
                                      :address       => "1.1.1.1",
                                      :cloud_tenant  => @ct1,
                                      :cloud_network => cloud_network_public)
            @ip2 = FactoryBot.create(:floating_ip,
                                      :address       => "2.2.2.2",
                                      :cloud_tenant  => @ct2,
                                      :cloud_network => cloud_network_public)
            @ip3 = FactoryBot.create(:floating_ip,
                                      :address       => "2.2.2.3",
                                      :cloud_tenant  => @ct2,
                                      :cloud_network => cloud_network_public_2)
          end

          it "#allowed_floating_ip_addresses with tenant selected" do
            workflow.values[:cloud_tenant]  = @ct2.id
            workflow.values[:cloud_network] = @cloud_network.id
            ips = workflow.allowed_floating_ip_addresses
            expect(ips.keys).to match_array [@ip2.id]
          end

          it "#allowed_floating_ip_addresses with tenant not selected" do
            workflow.values[:cloud_network] = @cloud_network.id
            ips = workflow.allowed_floating_ip_addresses
            expect(ips.keys).to match_array [@ip2.id, @ip1.id]
          end

          it "#allowed_floating_ip_addresses with network not connected to the router" do
            workflow.values[:cloud_network] = @cloud_network_2.id
            ips = workflow.allowed_floating_ip_addresses
            expect(ips.keys).to match_array []
          end
        end
      end
    end
  end

  describe "prepare_volumes_fields" do
    let(:workflow) do
      stub_dialog
      allow_any_instance_of(described_class).to receive(:update_field_visibility)
      described_class.new({:src_vm_id => template.id}, admin.userid)
    end

    context "converts numbered volume form fields into an array" do
      it "with no default values" do
        volumes = workflow.prepare_volumes_fields(
          :name_1 => "v1n", :size_1 => "v1s", :delete_on_terminate_1 => true,
          :name_2 => "v2n", :size_2 => "v2s", :delete_on_terminate_2 => false,
          :other_irrelevant_key => 1
        )
        expect(volumes.length).to eq(2)
        expect(volumes[0]).to eq(:name => "v1n", :size => "v1s", :delete_on_terminate => true)
        expect(volumes[1]).to eq(:name => "v2n", :size => "v2s", :delete_on_terminate => false)
      end
      it "with default size" do
        volumes = workflow.prepare_volumes_fields(
          :name_1 => "v1n", :size_1 => "v1s", :delete_on_terminate_1 => true,
          :name_2 => "v2n", :size_2 => "", :delete_on_terminate_2 => false,
          :name_3 => "v3n", :delete_on_terminate_3 => false,
          :other_irrelevant_key => 1
        )
        expect(volumes.length).to eq(3)
        expect(volumes[0]).to eq(:name => "v1n", :size => "v1s", :delete_on_terminate => true)
        expect(volumes[1]).to eq(:name => "v2n", :size => "1", :delete_on_terminate => false)
        expect(volumes[2]).to eq(:name => "v3n", :size => "1", :delete_on_terminate => false)
      end
      it "with empty name if only size given" do
        volumes = workflow.prepare_volumes_fields(
          :name_1 => "v1n", :size_1 => "v1s", :delete_on_terminate_1 => true,
          :size_2 => "v2s", :delete_on_terminate_2 => false,
          :other_irrelevant_key => 1
        )
        expect(volumes.length).to eq(2)
        expect(volumes[0]).to eq(:name => "v1n", :size => "v1s", :delete_on_terminate => true)
        expect(volumes[1]).to eq(:name => "", :size => "v2s", :delete_on_terminate => false)
      end
    end

    it "produces an empty array if there are no volume fields" do
      volumes = workflow.prepare_volumes_fields(:other_irrelevant_key => 1)
      expect(volumes.length).to eq(0)
    end
  end

  describe "#make_request" do
    let(:alt_user) { FactoryBot.create(:user_with_group) }

    it "creates and update a request" do
      EvmSpecHelper.local_miq_server
      stub_dialog(:get_pre_dialogs)
      stub_dialog(:get_dialogs)

      # if running_pre_dialog is set, it will run 'continue_request'
      workflow = described_class.new(values = {:running_pre_dialog => false}, admin)

      expect(AuditEvent).to receive(:success).with(
        :event        => "vm_provision_request_created",
        :target_class => "Vm",
        :userid       => admin.userid,
        :message      => "VM Provisioning requested by <#{admin.userid}> for Vm:#{template.id}"
      )

      # creates a request
      stub_get_next_vm_name

      # the dialogs populate this
      values.merge!(:src_vm_id => template.id, :vm_tags => [])

      request = workflow.make_request(nil, values)

      expect(request).to be_valid
      expect(request).to be_a_kind_of(MiqProvisionRequest)
      expect(request.request_type).to eq("template")
      expect(request.description).to eq("Provision from [#{template.name}] to [New VM]")
      expect(request.requester).to eq(admin)
      expect(request.userid).to eq(admin.userid)
      expect(request.requester_name).to eq(admin.name)

      # updates a request

      stub_get_next_vm_name

      workflow = described_class.new(values, alt_user)

      expect(AuditEvent).to receive(:success).with(
        :event        => "vm_provision_request_updated",
        :target_class => "Vm",
        :userid       => alt_user.userid,
        :message      => "VM Provisioning request updated by <#{alt_user.userid}> for Vm:#{template.id}"
      )
      workflow.make_request(request, values)
    end
  end
end

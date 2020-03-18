require 'fog/openstack'

describe ManageIQ::Providers::Openstack::InfraManager::Refresher do
  include Spec::Support::EmsRefreshHelper

  before(:each) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryBot.create(:ems_openstack_infra, :zone => zone, :hostname => "192.168.24.1",
                              :ipaddress => "192.168.24.1", :port => 5000, :api_version => 'v2',
                              :security_protocol => 'no-ssl')
    @ems.update_authentication(
      :default => {:userid => "admin", :password => "1fb03e3ec17f5840a5448ef2115a7ec7d645c982"})
  end

  it "will perform a full refresh" do
    2.times do # Run twice to verify that a second run with existing data does not change anything
      full_refresh

      assert_table_counts
      assert_ems
      assert_specific_host
      assert_mapped_stacks
      assert_specific_public_template
    end
  end

  it "will verify maintenance mode" do
    # We need VCR to match requests differently here because fog adds a dynamic
    #   query param to avoid HTTP caching - ignore_awful_caching##########
    #   https://github.com/fog/fog/blob/master/lib/fog/openstack/compute.rb#L308
    VCR.use_cassette("#{described_class.name.underscore}_rhos_juno_maintenance",
                     :match_requests_on => [:method, :host, :path]) do
      @ems.reload
      @ems.reset_openstack_handle
      Fog::OpenStack.instance_variable_set(:@version, nil)
      EmsRefresh.refresh(@ems)
      EmsRefresh.refresh(@ems.network_manager)
      @ems.reload

      @host = ManageIQ::Providers::Openstack::InfraManager::Host.all.order(:ems_ref).detect { |x| x.name.include?('(NovaCompute)') }

      expect(@host.maintenance).to eq(false)
      expect(@host.maintenance_reason).to be nil

      @host.set_node_maintenance
      EmsRefresh.refresh(@ems)
      @ems.reload
      @host.reload
      expect(@host.maintenance).to eq(true)
      expect(@host.maintenance_reason).to eq("CFscaledown")

      @host.unset_node_maintenance
      EmsRefresh.refresh(@ems)
      @ems.reload
      @host.reload
      expect(@host.maintenance).to eq(false)
      expect(@host.maintenance_reason).to be nil
    end
  end

  def full_refresh
    @ems.reload
    # Caching OpenStack info between runs causes the tests to fail with:
    #   VCR::Errors::UnusedHTTPInteractionError
    # Reset the cache so HTTP interactions are the same between runs.
    @ems.reset_openstack_handle

    # We need VCR to match requests differently here because fog adds a dynamic
    #   query param to avoid HTTP caching - ignore_awful_caching##########
    #   https://github.com/fog/fog/blob/master/lib/fog/openstack/compute.rb#L308
    VCR.use_cassette("#{described_class.name.underscore}_rhos_juno", :match_requests_on => [:method, :host, :path]) do
      Fog::OpenStack.instance_variable_set(:@version, nil)
      EmsRefresh.refresh(@ems)
      MiqQueue.where(:class_name => "EmsRefresh", :method_name => "refresh").destroy_all
      EmsRefresh.refresh(@ems.network_manager)
    end
    @ems.reload
  end

  def assert_table_counts
    expect(ExtManagementSystem.count).to         eq 2
    expect(EmsCluster.count).to                  eq 2
    expect(Host.count).to                        eq 2
    expect(OrchestrationStack.count).to          eq 301
    expect(OrchestrationStackParameter.count).to eq 2773
    expect(OrchestrationStackResource.count).to  eq 459
    expect(OrchestrationStackOutput.count).to    eq 398
    expect(OrchestrationTemplate.count).to       eq 151
    expect(CloudNetwork.count).to                eq 6
    expect(CloudSubnet.count).to                 eq 6
    expect(NetworkPort.count).to                 eq 17
    expect(VmOrTemplate.count).to                eq 5
    expect(OperatingSystem.count).to             eq 7
    expect(Hardware.count).to                    eq 7
    expect(Disk.count).to                        eq 2
    expect(ResourcePool.count).to                eq 0
    expect(Vm.count).to                          eq 0
    expect(CustomAttribute.count).to             eq 0
    expect(CustomizationSpec.count).to           eq 0
    expect(Lan.count).to                         eq 0
    expect(MiqScsiLun.count).to                  eq 0
    expect(MiqScsiTarget.count).to               eq 0
    expect(Snapshot.count).to                    eq 0
    expect(Switch.count).to                      eq 0
    expect(SystemService.count).to               eq 0
    expect(EmsFolder.count).to                   eq 0
    expect(Storage.count).to                     eq 0
  end

  def assert_ems
    expect(@ems).to have_attributes(
      :api_version       => 'v2',
      :security_protocol => 'no-ssl',
      :uid_ems           => nil
    )

    expect(@ems.ems_clusters.size).to                eq 2
    expect(@ems.hosts.size).to                       eq 2
    expect(@ems.orchestration_stacks.size).to        eq 301
    expect(@ems.direct_orchestration_stacks.size).to eq 1
    expect(@ems.vms_and_templates.size).to           eq 5
    expect(@ems.miq_templates.size).to               eq 5
    expect(@ems.customization_specs.size).to         eq 0
    expect(@ems.resource_pools.size).to              eq 0
    expect(@ems.storages.size).to                    eq 0
    expect(@ems.vms.size).to                         eq 0
    expect(@ems.ems_folders.size).to                 eq 0
  end

  def assert_specific_host
    @host = ManageIQ::Providers::Openstack::InfraManager::Host.all.detect { |x| x.name.include?('(Controller)') }

    expect(@host.ems_ref).not_to be nil
    expect(@host.uid_ems).not_to be nil
    expect(@host.mac_address).not_to be nil
    expect(@host.ipaddress).not_to be nil
    expect(@host.ems_cluster).not_to be nil

    expect(@host).to have_attributes(
      :ipmi_address       => nil,
      :vmm_vendor         => "redhat",
      :vmm_version        => nil,
      :vmm_product        => "rhel (No hypervisor, Host Type is Controller)",
      :power_state        => "on",
      :connection_state   => "connected",
      :service_tag        => nil,
      :maintenance        => false,
      :maintenance_reason => nil,
    )

    expect(@host.private_networks.count).to be > 0
    expect(@host.private_networks.first).to be_kind_of(ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Private)
    expect(@host.network_ports.count).to    be > 0
    expect(@host.network_ports.first).to    be_kind_of(ManageIQ::Providers::Openstack::NetworkManager::NetworkPort)

    expect(@host.operating_system).to have_attributes(
      :product_name     => "linux"
    )

    expect(@host.hardware).to have_attributes(
      # TODO(tzumainn) Introspection no longer finds these attributes, may be
      # an OpenStack issue?
      #:cpu_speed            => 3392,
      #:cpu_type             => "RHEL 7.2.0 PC (i440FX + PIIX, 1996)",
      #:manufacturer         => "Red Hat",
      #:model                => "KVM",
      #:bios                 => "seabios-1.7.5-11.el7",
      :memory_mb            => 32768,
      :memory_console       => nil,
      :disk_capacity        => 29,
      :cpu_sockets          => 8,
      :cpu_total_cores      => 8,
      :cpu_cores_per_socket => 1,
      :guest_os             => nil,
      :guest_os_full_name   => nil,
      :cpu_usage            => nil,
      :memory_usage         => nil,
      :number_of_nics       => 3,
    )

    # TODO(tzumainn) Introspection no longer finds disk attributes, may be
    # an OpenStack issue?
    #assert_specific_disk(@host.hardware.disks.first)
  end

  def assert_specific_disk(disk)
    expect(disk).to have_attributes(
      :device_name     => 'sda',
      :device_type     => 'disk',
      :controller_type => 'scsi',
      :present         => true,
      :filename        => 'ata-QEMU_HARDDISK_QM00005',
      :location        => nil,
      :size            => 57_982_058_496,
      :disk_type       => nil,
      :mode            => 'persistent')
  end

  def assert_specific_public_template
    assert_specific_template("overcloud-full-vmlinuz", true)
  end

  def assert_specific_template(name, is_public = false)
    template = ManageIQ::Providers::Openstack::InfraManager::Template.where(:name => name).first
    expect(template).to have_attributes(
      :template              => true,
      :publicly_available    => is_public,
      :vendor                => "openstack",
      :power_state           => "never",
      :location              => "unknown",
      :tools_status          => nil,
      :boot_time             => nil,
      :standby_action        => nil,
      :connection_state      => nil,
      :cpu_affinity          => nil,
      :memory_reserve        => nil,
      :memory_reserve_expand => nil,
      :memory_limit          => nil,
      :memory_shares         => nil,
      :memory_shares_level   => nil,
      :cpu_reserve           => nil,
      :cpu_reserve_expand    => nil,
      :cpu_limit             => nil,
      :cpu_shares            => nil,
      :cpu_shares_level      => nil
    )
    expect(template.ems_ref).to be_guid

    expect(template.ext_management_system).to eq @ems
    expect(template.operating_system).not_to be_nil
    expect(template.custom_attributes.size).to eq 0
    expect(template.snapshots.size).to         eq 0
    expect(template.hardware).not_to               be_nil
    expect(template.parent).to                     be_nil
    template
  end

  def assert_mapped_stacks
    expect(CloudNetwork.all.map { |x| "#{x.name}___#{x.orchestration_stack.try(:name)}" }).to(
      match_array(
        %w(
          external___overcloud-Networks-m2cvlqpcz5b2-ExternalNetwork-5uey56mcytii
          tenant___overcloud-Networks-m2cvlqpcz5b2-TenantNetwork-dar2ol7zf72w
          storage_mgmt___overcloud-Networks-m2cvlqpcz5b2-StorageMgmtNetwork-vbtdttrp6xbl
          internal_api___overcloud-Networks-m2cvlqpcz5b2-InternalNetwork-j3tyhpmhfonl
          storage___overcloud-Networks-m2cvlqpcz5b2-StorageNetwork-qyh4atckxw3a
          ctlplane___
        )
      )
    )

    expect(SecurityGroup.all.map { |x| "#{x.name}___#{x.orchestration_stack.try(:name)}" }).to(
      match_array(
        %w(
          default___
          default___
        )
      )
    )
  end
end

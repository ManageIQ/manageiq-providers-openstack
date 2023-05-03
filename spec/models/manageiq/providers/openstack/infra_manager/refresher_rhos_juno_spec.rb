require 'fog/openstack'

describe ManageIQ::Providers::Openstack::InfraManager::Refresher do
  include Spec::Support::EmsRefreshHelper

  before(:each) do
    zone = EvmSpecHelper.local_miq_server.zone
    credentials = Rails.application.secrets.openstack
    @ems = FactoryBot.create(:ems_openstack_infra, :zone => zone, :hostname => credentials[:hostname],
                              :ipaddress => credentials[:hostname], :port => credentials[:port].to_i, :api_version => 'v3',
                              :security_protocol => 'no-ssl', :uid_ems => "default")
    @ems.update_authentication(
      :default => {:userid => credentials[:userid], :password => credentials[:password]})
  end

  it "will perform a full refresh" do
    2.times do # Run twice to verify that a second run with existing data does not change anything
      full_refresh

      assert_table_counts
      assert_ems
      assert_specific_host
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

      @host = ManageIQ::Providers::Openstack::InfraManager::Host.all.find { |host| host.vmm_vendor == "redhat"}

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
    expect(EmsCluster.count).to                  eq 0
    expect(Host.count).to                        eq 1
    expect(OrchestrationStack.count).to          eq 0
    expect(OrchestrationStackParameter.count).to eq 0
    expect(OrchestrationStackResource.count).to  eq 0
    expect(OrchestrationStackOutput.count).to    eq 0
    expect(OrchestrationTemplate.count).to       eq 0
    expect(CloudNetwork.count).to                eq 0
    expect(CloudSubnet.count).to                 eq 0
    expect(NetworkPort.count).to                 eq 0
    expect(VmOrTemplate.count).to                eq 1
    expect(OperatingSystem.count).to             eq 2
    expect(Hardware.count).to                    eq 2
    expect(Disk.count).to                        eq 0
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
      :api_version       => 'v3',
      :security_protocol => 'no-ssl',
      :uid_ems           => 'default'
    )

    expect(@ems.ems_clusters.size).to                eq 0
    expect(@ems.hosts.size).to                       eq 1
    expect(@ems.orchestration_stacks.size).to        eq 0
    expect(@ems.direct_orchestration_stacks.size).to eq 0
    expect(@ems.vms_and_templates.size).to           eq 1
    expect(@ems.miq_templates.size).to               eq 1
    expect(@ems.customization_specs.size).to         eq 0
    expect(@ems.resource_pools.size).to              eq 0
    expect(@ems.storages.size).to                    eq 0
    expect(@ems.vms.size).to                         eq 0
    expect(@ems.ems_folders.size).to                 eq 0
  end

  def assert_specific_host
    @host = ManageIQ::Providers::Openstack::InfraManager::Host.all.find { |host| host.vmm_vendor == "redhat"}

    expect(@host.ems_ref).not_to be nil

    expect(@host).to have_attributes(
      :ipmi_address       => nil,
      :vmm_vendor         => "redhat",
      :vmm_version        => nil,
      :vmm_product        => nil,
      :power_state        => "unknown",
      :connection_state   => "disconnected",
      :service_tag        => nil,
      :maintenance        => false,
      :maintenance_reason => nil,
    )

    expect(@host.operating_system).to have_attributes(
      :product_name     => "linux"
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
    assert_specific_template("cirros", true)
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
end

require 'ostruct'
module OpenstackStubs
  def scaling_factor
    @data_scaling || try(:data_scaling) || 1
  end

  def disconnect_inv_factor
    @disconnect_inv_count || 0
  end

  def test_counts(scaling = nil)
    scaling ||= scaling_factor
    {
      :cloud_services_count            => scaling * 10,
      :cloud_tenants_count             => scaling * 10,
      :flavors_count                   => scaling * 10,
      :host_aggregates_count           => scaling * 10,
      :key_pairs_count                 => scaling * 5,
      :quotas_count                    => scaling * 10,
      :miq_templates_count             => scaling * 10,
      :orchestration_stacks_count      => scaling * 10,
      :vnfs_count                      => scaling * 10,
      :vnfds_count                     => scaling * 10,
      :vms_count                       => scaling * 10,
      :volume_templates_count          => scaling * 10,
      :volume_snapshot_templates_count => scaling * 10,
      :cloud_volume_backups_count      => scaling * 10,
    }
  end

  def assert_do_not_delete
    allow_any_instance_of(ApplicationRecord).to(
      receive(:delete).and_raise("Not allowed delete operation detected. The probable cause is a wrong manager_ref"\
                                 " causing create&delete instead of update")
    )
    allow_any_instance_of(ActiveRecord::Associations::CollectionProxy).to(
      receive(:delete).and_raise("Not allowed delete operation detected. The probable cause is a wrong manager_ref"\
                                 " causing create&delete instead of update")
    )
  end

  def mocked_availability_zones
    [OpenStruct.new(:zoneName => "nova")]
  end

  def mocked_cloud_services
    mocked_cloud_services = []
    test_counts[:cloud_services_count].times do |i|
      mocked_cloud_services << OpenStruct.new(
        :id              => i,
        :binary          => "binary_#{i}",
        :host            => "host_#{i}",
        :state           => "state_#{i}",
        :status          => "disabled",
        :disabled_reason => "disabled_reason_#{i}",
        :zone            => "nova"
      )
    end
    mocked_cloud_services
  end

  def mocked_cloud_tenants
    mocked_cloud_tenants = []
    test_counts[:cloud_tenants_count].times do |i|
      mocked_cloud_tenants << OpenStruct.new(
        :id          => i,
        :name        => "cloud_tenant_#{i}",
        :description => "cloud_tenant_description_#{i}",
        :enabled     => true
      )
    end
    mocked_cloud_tenants
  end

  def mocked_flavors
    mocked_flavors = []
    test_counts[:flavors_count].times do |i|
      mocked_flavors << OpenStruct.new(
        :id        => i,
        :name      => "flavor_#{i}",
        :disabled  => false,
        :vcpus     => i,
        :ram       => i,
        :is_public => i.even?,
        :disk      => i,
        :swap      => i,
        :ephemeral => i
      )
    end
    mocked_flavors
  end

  def mocked_server_groups
    []
  end

  def mocked_host_aggregates
    mocked_host_aggregates = []
    test_counts[:host_aggregates_count].times do |i|
      mocked_host_aggregates << OpenStruct.new(
        :id       => i,
        :name     => "host_aggregate_#{i}",
        :ems_ref  => i,
        :hosts    => [],
        :metadata => "host_aggregate_metadata_#{i}"
      )
    end
    mocked_host_aggregates
  end

  def mocked_key_pairs
    mocked_key_pairs = []
    test_counts[:key_pairs_count].times do |i|
      mocked_key_pairs << OpenStruct.new(
        :name        => "key_pair_#{i}",
        :fingerprint => "key_pair_fingerprint_#{i}"
      )
    end
    mocked_key_pairs
  end

  def mocked_quotas
    mocked_quotas = []
    test_counts[:quotas_count].times do |i|
      mocked_quotas << {
        :id           => i,
        :tenant_id    => i,
        :service_name => "compute",
        :quota_key_1  => "quota_value_1",
        :quota_key_2  => "quota_value_2"
      }
    end
    mocked_quotas
  end

  def mocked_miq_templates
    mocked_miq_templates = []
    test_counts[:miq_templates_count].times do |i|
      mocked_miq_templates << OpenStruct.new(
        :id          => "image_#{i}",
        :name        => "miq_template_#{i}",
        :owner       => i,
        :min_disk    => i,
        :min_ram     => i,
        :size        => i,
        :disk_format => "ext2",
        :is_public   => true,
        :visibility  => "public",
        :properties  => {'architecture' => '64'},
        :attributes  => {}
      )
    end
    mocked_miq_templates
  end

  def mocked_orchestration_stacks
    mocked_orchestration_stacks = []
    test_counts[:orchestration_stacks_count].times do |i|
      mocked_orchestration_stacks << OpenStruct.new(
        :id                  => i,
        :stack_name          => "orchestration_stack_#{i}",
        :description         => "orchestration_stack_description_#{i}",
        :stack_status        => "orchestration_stack_status_#{i}",
        :stack_status_reason => "orchestration_stack_status_reason_#{i}",
        :parent              => nil,
        :service             => OpenStruct.new(:current_tenant => {:id => i}),
        :template            => OpenStruct.new(
          :id          => i,
          :description => "orchestration_template_description_#{i}",
          :content     => "orchestration_template_content_#{i}",
          :format      => "HOT"
        ),
        :outputs             => [{
          'output_key'   => "output_key_#{i}",
          'output_value' => "output_value_#{i}",
          'description'  => "output_description_#{i}"
        }],
        :parameters          => {"OS::project_id" => "project_id_#{i}"},
        :links               => [{"href"=>"http://42.42.42.42:4242/v1/project_id_#{i}/stacks/orchestration_stack_#{i}/#{i}"}],
        :resources           => [OpenStruct.new(
          :physical_resource_id   => "vm_#{i}",
          :logical_resource_id    => "logical_resource_#{i}",
          :resource_type          => "resource_type_#{i}",
          :resource_Status        => "resource_status_#{i}",
          :resource_status_reason => "resource_status_reason_#{i}",
          :updated_time           => nil
        )]
      )
    end
    mocked_orchestration_stacks
  end

  def mocked_vnfs
    mocked_vnfs = []
    test_counts[:vnfs_count].times do |i|
      mocked_vnfs << OpenStruct.new(
        :id          => i,
        :name        => "vnf_#{i}",
        :description => "vnf_description_#{i}",
        :status      => "vnf_status_#{i}",
        :tenant_id   => i,
        :mgmt_url    => "vnf_mgmt_url_#{i}"
      )
    end
    mocked_vnfs
  end

  def mocked_vnfds
    mocked_vnfds = []
    test_counts[:vnfds_count].times do |i|
      mocked_vnfds << OpenStruct.new(
        :id             => i,
        :name           => "vnfd_#{i}",
        :description    => "vnfd_description_#{i}",
        :vnf_attributes => {"vnfd" => "vnfd_content_#{i}"}
      )
    end
    mocked_vnfds
  end

  def mocked_vms
    mocked_vms = []
    test_counts[:vms_count].times do |i|
      mocked_vms << OpenStruct.new(
        :id                 => "vm_#{i}",
        :name               => "vm_#{i}",
        :state              => "vm_state_#{i}",
        :image              => {"id" => i},
        :flavor             => {"id" => i},
        :availability_zone  => "nova",
        :private_ip_address => '10.10.10.1',
        :public_ip_address  => '172.1.1.2',
        :attributes         => {}
      )
    end
    mocked_vms
  end

  def mocked_volume_templates
    mocked_volume_templates = []
    test_counts[:volume_templates_count].times do |i|
      mocked_volume_templates << OpenStruct.new(
        :id         => "volume_template_#{i}",
        :name       => "volume_template_#{i}",
        :status     => "available",
        :attributes => {"bootable" => true}
      )
    end
    mocked_volume_templates
  end

  def mocked_volume_snapshot_templates
    mocked_volume_snapshot_templates = []
    test_counts[:volume_snapshot_templates_count].times do |i|
      mocked_volume_snapshot_templates << OpenStruct.new(
        :id        => "volume_snapshot_template_#{i}",
        :name      => "volume_snapshot_template_#{i}",
        :status    => "available",
        :volume_id => "volume_template_#{i}"
      )
    end
    mocked_volume_snapshot_templates
  end

  def mocked_cloud_volume_backups
    mocked_cloud_volume_backups = []
    test_counts[:cloud_volume_backups_count].times do |i|
      mocked_cloud_volume_backups << OpenStruct.new(
        :id   => "cloud_volume_backup_#{i}",
        :name => "cloud_volume_backup_#{i}",
      )
    end
    mocked_cloud_volume_backups
  end
end

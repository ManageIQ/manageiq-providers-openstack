namespace :vcr do
  namespace :cassettes do
    desc 'Deletes VCR cassettes for OpenStack Cloud Provider'
    task :delete => :environment do
      vcr_dir = ManageIQ::Providers::Openstack::Engine.root.join("spec/vcr_cassettes/manageiq/providers/openstack/cloud_manager")
      Dir.glob(vcr_dir.join("refresher*.yml")).each { |f| File.delete(f) }
    end
  end

  namespace :spec do
    desc 'Run specs needed for rerecording of VCRs'
    task :run => :environment do
      ENV['SPEC'] = Dir.glob(ManageIQ::Providers::Openstack::Engine.root.join("spec/models/manageiq/providers/openstack/cloud_manager/refresher_spec.rb")).first
      Rake::Task['spec'].invoke
    end
  end

  desc 'Rerecord all of VCR cassettes'
  task :rerecord => :environment do
    require 'fog/openstack'

    host, port, username, password = YAML.load_file("config/secrets.yml").dig("test", "openstack").values_at("hostname", "port", "userid", "password")

    Rake::Task['vcr:cassettes:delete'].invoke

    fog_connect_opts = {
      :provider               => "OpenStack",
      :openstack_auth_url     => "https://#{host}:#{port}/v3/",
      :openstack_username     => username,
      :openstack_api_key      => password,
      :openstack_project_name => "admin",
      :openstack_domain_id    => "default",
      :connection_options     => {:ssl_verify_peer => false}
    }

    compute = Fog::Compute.new(fog_connect_opts)
    network = Fog::Network.new(fog_connect_opts)

    begin
      puts "Creating resources..."
      cn = network.create_network(:name => "test-network")
      cn_id = cn.data.dig(:body, "network", "id")
      tenant_id = cn.data.dig(:body, "network", "tenant_id")
      cs = network.subnets.create(:network_id => cn_id, :cidr => "10.0.0.0/21", :ip_version => 4)
      router = network.create_router("test-router")
      router_id = router.data.dig(:body, "router", "id")
      sg = network.create_security_group(:name => "test-sg-group", :description => "test description", :tenant_id => tenant_id)
      sg_id = sg.data.dig(:body, "security_group", "id")

      image = compute.images.first
      flavor = compute.flavors.get(1)
      vm = compute.servers.create(:name => 'test-server', :flavor_ref => flavor.id, :image_ref => image.id, :nics => [{:net_id => cn_id}])
      compute.create_key_pair("test-key")
      vol = compute.create_volume("test-vol", "test description", 1)
      vol_id = vol.data.dig(:body, "volume", "id")
      agg = compute.create_aggregate("test-aggregate")
      agg_id = agg.data.dig(:body, "aggregate", "id")
    rescue => err
      puts err
    end

    puts "Generating VCRs..."
    `bundle exec rspec ./spec/models/manageiq/providers/openstack/cloud_manager/refresher_spec.rb`

    puts "Cleaning up resources..."
    compute.delete_server(vm.id)
    compute.delete_key_pair("test-key")
    compute.delete_volume(vol_id)
    compute.delete_aggregate(agg_id)

    10.times do
      sleep(10)
    end

    network.delete_subnet(cs.id)

    10.times do
      sleep(10)
    end

    network.delete_network(cn_id)
    network.delete_security_group(sg_id)
    network.delete_router(router_id)
  end
end

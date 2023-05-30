namespace :vcr do
  namespace :cassettes do
    desc 'Deletes VCR cassettes for OpenStack Cloud Provider'
    task :delete => :environment do
      vcr_dir = ManageIQ::Providers::Openstack::Engine.root.join("spec/vcr_cassettes/manageiq/providers/openstack/cloud_manager")
      Dir.glob(vcr_dir.join("**/refresher*.yml")).each { |f| File.delete(f) }
    end
  end

  namespace :spec do
    desc 'Run specs needed for rerecording of VCRs'
    task :run => :environment do
      puts "Generating VCRs..."
      ENV['SPEC'] = Dir.glob(ManageIQ::Providers::Openstack::Engine.root.join("spec/models/manageiq/providers/openstack/cloud_manager/refresher_spec.rb")).first
      Rake::Task['spec'].invoke
    end
  end

  namespace :environment do
    def secrets_yml
      @secrets_yml ||= YAML.load_file("config/secrets.yml").dig("test", "openstack")
    end

    def fog_connect_opts
      host, port, username, password = secrets_yml.values_at("hostname", "port", "userid", "password")

      {
        :openstack_auth_url     => "https://#{host}:#{port}/v3/",
        :openstack_username     => username,
        :openstack_api_key      => password,
        :openstack_project_name => "admin",
        :openstack_domain_id    => "default",
        :connection_options     => {:ssl_verify_peer => false}
      }
    end

    def compute_client
      @compute_client ||= begin
        require 'fog/openstack'
        Fog::OpenStack::Compute.new(fog_connect_opts)
      end
    end

    def network_client
      @network_client ||= begin
        require 'fog/openstack'
        Fog::OpenStack::Network.new(fog_connect_opts)
      end
    end

    def identity_client
      @identity_client ||= begin
        require 'fog/openstack'
        Fog::OpenStack::Identity.new(fog_connect_opts)
      end
    end

    def with_retry(retry_count: 10, retry_sleep: 10)
      retry_count.times do
        yield
        sleep(retry_sleep)
      rescue Fog::OpenStack::Compute::NotFound
        break
      end
    end

    desc 'Initialize environment with resources'
    task :create => :environment do
      puts "Creating resources..."
      cn = network_client.create_network(:name => "manageiq-spec-network").body["network"]
      cn_id = cn["id"]
      tenant_id = cn["tenant_id"]
      network_client.subnets.create(:network_id => cn_id, :cidr => "10.0.0.0/21", :ip_version => 4)
      network_client.create_router("manageiq-spec-router")
      network_client.create_port(cn_id, :name => "manageiq-spec-port")
      network_client.create_security_group(:name => "manageiq-spec-sg", :description => "test description", :tenant_id => tenant_id)

      image = compute_client.images.first
      flavor = compute_client.flavors.get(1)
      compute_client.servers.create(:name => 'manageiq-spec-server', :flavor_ref => flavor.id, :image_ref => image.id, :nics => [{:net_id => cn_id}])
      compute_client.create_key_pair("manageiq-spec-key")
      compute_client.create_volume("manageiq-spec-vol", "test description", 1)
      compute_client.create_aggregate("manageiq-spec-aggregate")

      project = identity_client.create_project(:name => 'manageiq-spec-project', :description => "test description").body["project"]
      role = identity_client.list_roles.body["roles"].find { |roles| roles["name"] == "admin" }
      user = identity_client.list_users.body["users"].find { |users| users["name"] == "admin" }
      identity_client.grant_project_user_role(project["id"], user["id"], role["id"])
    rescue => err
      puts err
    end

    desc 'Cleanup resources from environment'
    task :cleanup => :environment do
      vm = compute_client.list_servers.body["servers"].find { |vms| vms["name"] == "manageiq-spec-server" }
      key = compute_client.list_key_pairs.body["keypairs"].find { |keys| keys["keypair"]["name"] == "manageiq-spec-key" }
      vol = compute_client.list_volumes_detail.body["volumes"].find { |vols| vols["displayName"] == "manageiq-spec-vol" }
      agg = compute_client.list_aggregates.body["aggregates"].find { |aggs| aggs["name"] == "manageiq-spec-aggregate" }
      cn = network_client.list_networks.body["networks"].find { |cns| cns["name"] == "manageiq-spec-network" }
      cs = network_client.list_subnets.body["subnets"].find { |subnets| subnets["network_id"] == cn["id"] }
      router = network_client.list_routers.body["routers"].find { |routers| routers["name"] == "manageiq-spec-router" }
      port = network_client.list_ports.body["ports"].find { |ports| ports["name"] == "manageiq-spec-port" }
      sg = network_client.list_security_groups.body["security_groups"].find { |sgs| sgs["name"] == "manageiq-spec-sg" }
      tenant = identity_client.list_projects.body["projects"].find { |tenants| tenants["name"] == "manageiq-spec-project" }

      puts "Cleaning up resources..."
      compute_client.delete_server(vm["id"]) unless vm.nil?
      compute_client.delete_key_pair(key["keypair"]["name"]) unless key.nil?
      compute_client.delete_volume(vol["id"]) unless vol.nil?
      compute_client.delete_aggregate(agg["id"]) unless agg.nil?

      with_retry { compute_client.get_server_details(vm["id"]) } unless vm.nil?

      network_client.delete_port(port["id"]) unless port.nil?
      network_client.delete_subnet(cs["id"]) unless cs.nil?
      network_client.delete_network(cn["id"]) unless cn.nil?
      network_client.delete_security_group(sg["id"]) unless sg.nil?
      network_client.delete_router(router["id"]) unless router.nil?

      identity_client.delete_project(tenant["id"]) unless tenant.nil?
    end
  end

  desc 'Rerecord all of VCR cassettes'
  task :rerecord => :environment do
    Rake::Task['vcr:cassettes:delete'].invoke
    Rake::Task['vcr:environment:create'].invoke
    Rake::Task['vcr:spec:run'].invoke
  ensure
    Rake::Task['vcr:environment:cleanup'].invoke
  end
end

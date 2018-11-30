class VcrRecorder
  OBFUSCATED_PASSWORD = "password_2WpEraURh"
  OBFUSCATED_IP = "11.22.33.44"

  def base_dir
    Rake.application.original_dir
  end

  def vcr_base_dir
    File.join(base_dir, 'spec/vcr_cassettes/manageiq/providers/openstack/cloud_manager')
  end

  def vcr_files
    Dir.glob(File.join(vcr_base_dir, 'refresher_rhos_*.yml'))
  end

  def test_base_dir
    File.join(base_dir, 'spec/models/manageiq/providers/openstack/cloud_manager')
  end

  def test_files
    Dir.glob(File.join(test_base_dir, 'refresher_*_spec.rb'))
  end

  def openstack_environment_file
    File.join(base_dir, "openstack_environments.yml")
  end

  def openstack_environments
    @openstack_environments ||= YAML.load_file(openstack_environment_file)
  end

  def load_credentials
    openstack_environments.each do |env|
      env_name = env.keys.first
      env      = env[env_name]

      puts "-------------------------------------------------------------------------------------------------------------"
      puts "Loading enviroment credentials for #{env_name}"
      file_name = File.join(test_base_dir, "refresher_rhos_#{env_name}_spec.rb")
      change_file(file_name, OBFUSCATED_PASSWORD, env["password"], OBFUSCATED_IP, env["ip"])

      file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}_with_errors.yml")
      change_file(file_name, OBFUSCATED_PASSWORD, env["password"], OBFUSCATED_IP, env["ip"])

      file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}.yml")
      change_file(file_name, OBFUSCATED_PASSWORD, env["password"], OBFUSCATED_IP, env["ip"])

      file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}_fast_refresh.yml")
      change_file(file_name, OBFUSCATED_PASSWORD, env["password"], OBFUSCATED_IP, env["ip"])

      file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}_legacy_fast_refresh.yml")
      change_file(file_name, OBFUSCATED_PASSWORD, env["password"], OBFUSCATED_IP, env["ip"])

      file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}_vm_targeted_refresh.yml")
      change_file(file_name, OBFUSCATED_PASSWORD, env["password"], OBFUSCATED_IP, env["ip"])

      file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}_stack_targeted_refresh.yml")
      change_file(file_name, OBFUSCATED_PASSWORD, env["password"], OBFUSCATED_IP, env["ip"])

      file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}_tenant_targeted_refresh.yml")
      change_file(file_name, OBFUSCATED_PASSWORD, env["password"], OBFUSCATED_IP, env["ip"])

      file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}_network_targeted_refresh.yml")
      change_file(file_name, OBFUSCATED_PASSWORD, env["password"], OBFUSCATED_IP, env["ip"])

      file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}_router_targeted_refresh.yml")
      change_file(file_name, OBFUSCATED_PASSWORD, env["password"], OBFUSCATED_IP, env["ip"])

      file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}_port_targeted_refresh.yml")
      change_file(file_name, OBFUSCATED_PASSWORD, env["password"], OBFUSCATED_IP, env["ip"])

      file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}_volume_targeted_refresh.yml")
      change_file(file_name, OBFUSCATED_PASSWORD, env["password"], OBFUSCATED_IP, env["ip"])
    end
  end

  def obfuscate_credentials
    openstack_environments.each do |env|
      env_name = env.keys.first
      env      = env[env_name]

      puts "-------------------------------------------------------------------------------------------------------------"
      puts "Obfuscating enviroment credentials for #{env_name}"
      file_name = File.join(test_base_dir, "refresher_rhos_#{env_name}_spec.rb")
      change_file(file_name, env["password"], OBFUSCATED_PASSWORD, env["ip"], OBFUSCATED_IP)

      file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}_with_errors.yml")
      change_file(file_name, env["password"], OBFUSCATED_PASSWORD, env["ip"], OBFUSCATED_IP)

      file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}.yml")
      change_file(file_name, env["password"], OBFUSCATED_PASSWORD, env["ip"], OBFUSCATED_IP)

      file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}_fast_refresh.yml")
      change_file(file_name, env["password"], OBFUSCATED_PASSWORD, env["ip"], OBFUSCATED_IP)

      file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}_legacy_fast_refresh.yml")
      change_file(file_name, env["password"], OBFUSCATED_PASSWORD, env["ip"], OBFUSCATED_IP)

      file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}_vm_targeted_refresh.yml")
      change_file(file_name, env["password"], OBFUSCATED_PASSWORD, env["ip"], OBFUSCATED_IP)

      file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}_stack_targeted_refresh.yml")
      change_file(file_name, env["password"], OBFUSCATED_PASSWORD, env["ip"], OBFUSCATED_IP)

      file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}_tenant_targeted_refresh.yml")
      change_file(file_name, env["password"], OBFUSCATED_PASSWORD, env["ip"], OBFUSCATED_IP)

      file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}_network_targeted_refresh.yml")
      change_file(file_name, env["password"], OBFUSCATED_PASSWORD, env["ip"], OBFUSCATED_IP)

      file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}_router_targeted_refresh.yml")
      change_file(file_name, env["password"], OBFUSCATED_PASSWORD, env["ip"], OBFUSCATED_IP)

      file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}_port_targeted_refresh.yml")
      change_file(file_name, env["password"], OBFUSCATED_PASSWORD, env["ip"], OBFUSCATED_IP)

      file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}_volume_targeted_refresh.yml")
      change_file(file_name, env["password"], OBFUSCATED_PASSWORD, env["ip"], OBFUSCATED_IP)
    end
  end

  def change_file(file_name, from_password, to_password, from_ip, to_ip)
    return unless File.exist?(file_name)

    file = File.read(file_name)
    file.gsub!(from_password, to_password)
    file.gsub!(from_ip, to_ip)

    File.open(file_name, 'w') do |out|
      out << file
    end
  end

  def delete_cassettes
    vcr_files.each do |file|
      File.delete(file)
    end
  end

end

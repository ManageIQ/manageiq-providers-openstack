if ENV['CI']
  require 'simplecov'
  SimpleCov.start
end

Dir[Rails.root.join("spec/shared/**/*.rb")].each { |f| require f }
Dir[File.join(__dir__, "support/**/*.rb")].each { |f| require f }

require "manageiq/providers/openstack"

RSpec.configure do |config|
  config.filter_run_excluding(:qpid_proton) unless ENV['CI'] || Gem.loaded_specs.key?(:qpid_proton)
end

def fix_token_expires_at(interaction)
  data = JSON.parse(interaction.response.body)
  data["token"]["expires_at"] = "9999-12-31T23:59:59.999999Z"
  interaction.response.body = data.to_json.force_encoding('ASCII-8BIT')
end

VCR.configure do |config|
  config.ignore_hosts 'codeclimate.com' if ENV['CI']
  config.cassette_library_dir = File.join(ManageIQ::Providers::Openstack::Engine.root, 'spec/vcr_cassettes')

  config.before_record do |interaction|
    fix_token_expires_at(interaction) if interaction.request.uri.end_with?("v3/auth/tokens")
  end

  secrets = Rails.application.secrets
  secrets.openstack.each_key do |secret|
    config.define_cassette_placeholder(secrets.openstack_defaults[secret]) { secrets.openstack[secret] }
  end
end

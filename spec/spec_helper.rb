if ENV['CI']
  require 'simplecov'
  SimpleCov.start
end

Dir[Rails.root.join("spec/shared/**/*.rb")].each { |f| require f }
Dir[File.join(__dir__, "support/**/*.rb")].each { |f| require f }

require "manageiq-providers-openstack"

VCR.configure do |config|
  config.ignore_hosts 'codeclimate.com' if ENV['CI']
  config.cassette_library_dir = File.join(ManageIQ::Providers::Openstack::Engine.root, 'spec/vcr_cassettes')
end

RSpec.configure do |config|
  config.before(:suite) do
    NotificationType.seed
  end

  config.after(:suite) do
    NotificationType.delete_all
  end
end

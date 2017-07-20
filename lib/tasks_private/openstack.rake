require 'vcr_recorder'

namespace :vcr do
  namespace :credentials do
    desc 'Load credentials from openstack_environments.yml'
    task :load do
      VcrRecorder.new.load_credentials
    end
    desc 'Obfuscate real credentials from specs and cassettes'
    task :obfuscate do
      VcrRecorder.new.obfuscate_credentials
    end
  end

  namespace :cassettes do
    desc 'Deletes VCR cassettes for OpenStack Cloud Provider'
    task :delete do
      VcrRecorder.new.delete_cassettes
    end
  end

  namespace :spec do
    desc 'Run specs needed for rerecording of VCRs'
    task :run do
      ENV['SPEC'] = VcrRecorder.new.test_files.join(' ')
      Rake::Task['spec'].invoke
    end
  end

  desc 'Rerecord all of VCR cassettes'
  task :rerecord => [] do
    Rake::Task['vcr:cassettes:delete'].invoke
    Rake::Task['vcr:credentials:load'].invoke
    Rake::Task['vcr:spec:run'].invoke
    Rake::Task['vcr:credentials:obfuscate'].invoke
  end
end

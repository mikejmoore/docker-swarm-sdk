require 'bundler/setup'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rspec/its'

require 'single_cov'
require 'byebug'

# avoid coverage failure from lower docker versions not running all tests
if !ENV['DOCKER_VERSION'] || ENV['DOCKER_VERSION'] =~ /^1\.\d\d/
  SingleCov.setup :rspec
end

require 'docker'

ENV['DOCKER_API_USER']  ||= 'debbie_docker'
ENV['DOCKER_API_PASS']  ||= '*************'
ENV['DOCKER_API_EMAIL'] ||= 'debbie_docker@example.com'

RSpec.shared_context "local paths" do
  def project_dir
    File.expand_path(File.join(File.dirname(__FILE__), '..'))
  end
end

module SpecHelpers
  def skip_without_auth
    skip "Disabled because of missing auth" if ENV['DOCKER_API_USER'] == 'debbie_docker'
  end
end

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.mock_with :rspec
  config.color = true
  config.formatter = :documentation
  config.tty = true
  config.include SpecHelpers

  case ENV['DOCKER_VERSION']
  when /^1\.6/
    config.filter_run_excluding :docker_1_8 => true
    config.filter_run_excluding :docker_1_9 => true
    config.filter_run_excluding :docker_1_10 => true
  when /^1\.7/
    config.filter_run_excluding :docker_1_8 => true
    config.filter_run_excluding :docker_1_9 => true
    config.filter_run_excluding :docker_1_10 => true
  when /^1\.8/
    config.filter_run_excluding :docker_1_9 => true
    config.filter_run_excluding :docker_1_10 => true
  when /^1\.9/
    config.filter_run_excluding :docker_1_10 => true
  end
end

def init_test_swarm(master_connection)
  master_ip = master_connection.url.split("//").last.split(":").first
  master_swarm_port = 2377
  swarm_init_options = {
      "ListenAddr" => "0.0.0.0:#{master_swarm_port}",
      "AdvertiseAddr" => "#{master_ip}:#{master_swarm_port}",
      "ForceNewCluster" => false,
      "Spec" => {
        "Orchestration" => {},
        "Raft" => {},
        "Dispatcher" => {},
        "CAConfig" => {}
      }
    }

  puts "Manager node intializing swarm"
  swarm = Docker::Swarm::Swarm.init(swarm_init_options, master_connection)
end


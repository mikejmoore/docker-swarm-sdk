require 'spec_helper'
require_relative '../../../lib/docker-swarm'
require 'retry_block'
require 'byebug'


#DOCKER_VERSION=1.12 SWARM_MASTER_ADDRESS=http://192.168.40.24:2375 SWARM_WORKER_ADDRESS=http://192.168.40.50:2375 RAILS_ENV=test rspec ./spec/docker/swarm/node_spec.rb

describe Docker::Swarm::Network do

  it "Can create an overlay network for a swarm" do
    # CREATE A SWARM
    master_connection = Docker::Swarm::Connection.new(ENV['SWARM_MASTER_ADDRESS'])
    
    puts "Clean up old swarm configs if they exist ..."
    Docker::Swarm::Swarm.leave(true, master_connection)
    
    swarm = init_test_swarm(master_connection)

    puts "Find, or create network for the test service ..."
    network_name = "overlay#{Time.now.to_i}"
    network = swarm.find_network_by_name(network_name)
    if (network)
      network.remove
    end
    
    network = swarm.create_network_overlay(network_name) if (!network)
    
    network_from_search = swarm.find_network_by_name(network_name)
    expect(network_from_search).to_not be nil
    
    network.remove
    network_from_search = swarm.find_network_by_name(network_name)
    expect(network_from_search).to be nil
  end
  
  
end
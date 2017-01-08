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

    manager_node = swarm.manager_nodes.first

    network_name = "overlay#{Time.now.to_i}"
    network = manager_node.find_network_by_name(network_name)
    if (network)
      network.remove
    end
    
    #subnet = "10.#{50 + Random.rand(10)}.0.0/20"
    network = swarm.create_network_overlay(network_name)
    expect(network.driver).to eq "overlay"
    
    network_from_search = manager_node.find_network_by_name(network_name)
    expect(network_from_search).to_not be nil
    
    network.remove
    network_from_search = manager_node.find_network_by_name(network_name)
    expect(network_from_search).to be nil
    Docker::Swarm::Swarm.leave(true, master_connection)
  end
  
  it "Creating overlay network creates a unique subnet" do
    master_connection = Docker::Swarm::Connection.new(ENV['SWARM_MASTER_ADDRESS'])
    
    puts "Clean up old swarm configs if they exist ..."
    Docker::Swarm::Swarm.leave(true, master_connection)
    swarm = init_test_swarm(master_connection)
    manager_node = swarm.manager_nodes.first
    networks = []
    
    # Create 10 networks and make sure they all have unique subnet
    used_subnets = []
    (1..10).each do |index|
      network_name = "network#{index}"
      network = manager_node.find_network_by_name(network_name)
      if (network)
        network.remove
      end
      network = swarm.create_network_overlay(network_name)
      networks << network

      expect(network.subnets.length).to eq 1
      network.subnets.each do |sub_config| 
        subnet = sub_config['Subnet']
        expect(subnet.length > 1).to be true
        expect(used_subnets.include? subnet).to be false
        used_subnets << subnet
      end
    end
    expect(used_subnets.length).to eq 10
    networks.each do |network|
      network.remove
    end
    Docker::Swarm::Swarm.leave(true, master_connection)
  end
  
end
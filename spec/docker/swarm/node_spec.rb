require 'spec_helper'
require_relative '../../../lib/docker-swarm'
require 'retry_block'
#DOCKER_VERSION=1.12 SWARM_MASTER_ADDRESS=http://192.168.40.24:2375 SWARM_WORKER_ADDRESS=http://192.168.40.50:2375 RAILS_ENV=test rspec ./spec/docker/swarm/node_spec.rb

describe Docker::Swarm::Node do
  describe '#all' do
    it "Retrieves all Nodes" do
      
      raise "Must define env variable: SWARM_MASTER_ADDRESS" if (!ENV['SWARM_MASTER_ADDRESS'])
      raise "Must define env variable: SWARM_WORKER_ADDRESS" if (!ENV['SWARM_WORKER_ADDRESS'])
      
      swarm = nil
      master_address = ENV['SWARM_MASTER_ADDRESS']
      master_ip = master_address.split("//").last.split(":").first
      worker_address = ENV['SWARM_WORKER_ADDRESS']
      worker_ip = worker_address.split("//").last.split(":").first
      network_name = "app.1"

      master_connection = Docker::Swarm::Connection.new(master_address)
      worker_connection = Docker::Swarm::Connection.new(worker_address)
      
      Docker::Swarm::Swarm.leave(true, worker_connection)
      Docker::Swarm::Swarm.leave(true, master_connection)

      begin
        network = Docker::Swarm::Network::find_by_name(network_name, master_connection)
        network.remove() if (network)
        
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
        expect(swarm.connection).to eq master_connection
    
        # puts "Getting info about new swarm environment"
        # swarm = Docker::Swarm::Swarm.swarm({}, master_connection)
        expect(swarm).to_not be nil
      
        nodes = swarm.nodes()
        expect(nodes.length).to eq 1
        expect(swarm.manager_nodes.length).to eq 1
        
      
        puts "Worker joining swarm"
        swarm.join_worker(worker_connection)
      
        puts "View all nodes of swarm (count should be 2)"
        nodes = swarm.nodes
        expect(nodes.length).to eq 2
        expect(swarm.manager_nodes.length).to eq 1
      
        network = swarm.create_network(network_name)
        service_create_options = {
          "Name" => "nginx",
          "TaskTemplate" => {
            "ContainerSpec" => {
              "Networks" => [network.id],
              "Image" => "nginx:1.11.7",
              "Mounts" => [
              ],
              "User" => "root"
            },
            "Env" => ["TEST_ENV=test"],
            "LogDriver" => {
              "Name" => "json-file",
              "Options" => {
                "max-file" => "3",
                "max-size" => "10M"
              }
            },
             "Placement" => {},
             "Resources" => {
               "Limits" => {
                 "MemoryBytes" => 104857600
               },
               "Reservations" => {
               }
             },
            "RestartPolicy" => {
              "Condition" => "on-failure",
              "Delay" => 1,
              "MaxAttempts" => 3
            }
          },
          "Mode" => {
            "Replicated" => {
              "Replicas" => 5
            }
          },
          "UpdateConfig" => {
            "Delay" => 2,
            "Parallelism" => 2,
            "FailureAction" => "pause"
          },
          "EndpointSpec" => {
            "Ports" => [
              # {
              #   "Protocol" => "tcp",
              #   "PublishedPort" => 8181,
              #   "TargetPort" => 80
              # }
            ]
          },
          "Labels" => {
            "foo" => "bar"
          }
        }
        
        service = swarm.create_service(service_create_options)
        
        retry_block(attempts: 20, :sleep => 1) do |attempt|
          puts "Waiting for tasks to start up..."
          tasks = swarm.tasks
          running_count = 0
          tasks.each do |task|
            if (task.status == :running)
              running_count += 1
            end
          end
          expect(running_count).to eq 5
          sleep 1
        end
        

        manager_nodes = swarm.manager_nodes
        expect(manager_nodes.length).to eq 1
      
        worker_nodes = swarm.worker_nodes
        expect(worker_nodes.length).to eq 1

        # Drain worker
        worker_node = worker_nodes.first
        worker_node.drain

        retry_block(attempts: 20, :sleep => 1) do |attempt|
          puts "Waiting for node to drain and tasks to relocate..."
          tasks = swarm.tasks
          running_count = 0
          tasks.each do |task|
            if (task.status == :running)
              expect(task.node_id).to_not eq worker_node.id
              running_count += 1
            end
          end
          expect(running_count).to eq 5
          sleep 1
        end
      
        puts "Scale service to 10 replicas"
        service.scale(10)
        

        retry_block(attempts: 20, :sleep => 1) do |attempt|
          tasks = swarm.tasks
          tasks.select! {|t| t.status != :shutdown}
          expect(tasks.length).to eq 10
        end
      
      
        puts "Worker leaves the swarm"
        swarm.leave(worker_node)
        retry_block(attempts: 20, :sleep => 1) do |attempt|
          worker_node.refresh
          expect(worker_node.status).to eq 'down'
        end

        tasks = swarm.tasks
        tasks.select! {|t| t.status != :shutdown}
        expect(tasks.length).to eq 10
        
        worker_node.remove()
        expect(swarm.worker_nodes.length).to eq 0
      
        puts "Remove service"
        service.remove()

        retry_block(attempts: 20, :sleep => 1) do |attempt|
          tasks = swarm.tasks
          expect(tasks.length).to eq 0
        end
      ensure
        puts "Removing swarm ..."
        swarm.remove if (swarm)
      end
      
    end
  end
end
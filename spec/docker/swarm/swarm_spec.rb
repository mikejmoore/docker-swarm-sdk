require 'spec_helper'
require_relative '../../../lib/docker-swarm'
require 'retry_block'


#DOCKER_VERSION=1.12 SWARM_MASTER_ADDRESS=http://192.168.40.24:2375 SWARM_WORKER_ADDRESS=http://192.168.40.50:2375 RAILS_ENV=test rspec ./spec/docker/swarm/node_spec.rb

describe Docker::Swarm::Swarm do
  
  DEFAULT_SERVICE_SETTINGS = {
      "Name" => "nginx",
      "TaskTemplate" => {
        "ContainerSpec" => {
          "Networks" => [],
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
          "Replicas" => 3
        }
      },
      "UpdateConfig" => {
        "Delay" => 2,
        "Parallelism" => 2,
        "FailureAction" => "pause"
      },
      "EndpointSpec" => {
        "Ports" => [
          {
            "Protocol" => "tcp",
            "PublishedPort" => 8181,
            "TargetPort" => 80
          }
        ]
      },
      "Labels" => {
        "foo" => "bar"
      }
    }
    


  it "Can attach to a running swarm" do

    # CREATE A SWARM
    master_connection = Docker::Swarm::Connection.new(ENV['SWARM_MASTER_ADDRESS'])
    worker_connection = Docker::Swarm::Connection.new(ENV['SWARM_WORKER_ADDRESS'])
    
    puts "Clean up old swarm configs if they exist ..."
    Docker::Swarm::Swarm.leave(true, worker_connection)
    Docker::Swarm::Swarm.leave(true, master_connection)
    
    swarm = init_test_swarm(master_connection)
    worker_node = swarm.join_worker(worker_connection)
    expect(worker_node.hash).to_not be nil
    
    puts "Config and create a test swarm ..."
    service_create_options = DEFAULT_SERVICE_SETTINGS
    service_create_options['TaskTemplate']['Env'] << "TEST_ENV=test"
    service_create_options["Mode"]["Replicated"]["Replicas"] = 20
    service_create_options["EndpointSpec"]["Ports"] = [{"Protocol" => "tcp", "PublishedPort" => 8181, "TargetPort" => 80}]
    service = swarm.create_service(service_create_options)
    expect(swarm.services.length).to eq 1
    
    # ATTACH TO EXISTING SWARM
    swarm = Docker::Swarm::Swarm.find(master_connection, {discover_nodes: true, docker_api_port: 2375})
    expect(swarm).to_not be nil
    expect(swarm.services.length).to eq 1
    expect(swarm.nodes.length).to eq 2
  end
  
  
  it "Can remove working node gracefully" do
    master_connection = Docker::Swarm::Connection.new(ENV['SWARM_MASTER_ADDRESS'])
    worker_connection = Docker::Swarm::Connection.new(ENV['SWARM_WORKER_ADDRESS'])
    
    puts "Clean up old swarm configs if they exist ..."
    Docker::Swarm::Swarm.leave(true, worker_connection)
    begin
      Docker::Swarm::Swarm.leave(true, master_connection)
    rescue Exception => e
    end
    
    swarm = init_test_swarm(master_connection)
    worker_node = swarm.join_worker(worker_connection)
    expect(worker_node.hash).to_not be nil
    
    puts "Config and create a test swarm ..."
    service_create_options = DEFAULT_SERVICE_SETTINGS
    service_create_options['TaskTemplate']['Env'] << "TEST_ENV=test"
    service_create_options["Mode"]["Replicated"]["Replicas"] = 20
    service_create_options["EndpointSpec"]["Ports"] = [{"Protocol" => "tcp", "PublishedPort" => 8181, "TargetPort" => 80}]
    service = swarm.create_service(service_create_options)
    
    expect(swarm.services.length).to eq 1
    
    retry_block(attempts: 40, :sleep => 1) do |attempt|
      puts "Waiting for tasks to start up..."
      tasks = swarm.tasks
      running_count = 0
      tasks.each do |task|
        if (task.status == :running)
          running_count += 1
        end
      end
      expect(running_count).to eq 20
      sleep 1
    end
    
    puts "Removing worker node to force service to allocate tasks all to the master ..."
    worker_node.remove()
    
    retry_block(attempts: 20, :sleep => 1) do |attempt|
      puts "Waiting for tasks to all relocate after removing worker node ..."
      tasks = swarm.tasks
      running_count = 0
      tasks.each do |task|
        running_count += 1 if (task.status == :running)
      end
      expect(running_count).to eq 20
    end
    
    swarm.remove()
  end
  
  
  describe 'Swarm creation with 2 nodes' do
    it "Can add and scale service" do
      raise "Must define env variable: SWARM_MASTER_ADDRESS" if (!ENV['SWARM_MASTER_ADDRESS'])
      raise "Must define env variable: SWARM_WORKER_ADDRESS" if (!ENV['SWARM_WORKER_ADDRESS'])
      
      swarm = nil
      master_address = ENV['SWARM_MASTER_ADDRESS']
      master_ip = master_address.split("//").last.split(":").first
      worker_address = ENV['SWARM_WORKER_ADDRESS']
      worker_ip = worker_address.split("//").last.split(":").first

      master_connection = Docker::Swarm::Connection.new(master_address)
      worker_connection = Docker::Swarm::Connection.new(worker_address)

      Docker::Swarm::Swarm.leave(true, worker_connection)
      Docker::Swarm::Swarm.leave(true, master_connection)

      begin
        swarm = init_test_swarm(master_connection)
        
        expect(swarm.connection).to eq master_connection
        swarm = Docker::Swarm::Swarm.find(master_connection)
        expect(swarm.connection).to_not be nil
    
        puts "Getting info about new swarm environment"
        swarm = Docker::Swarm::Swarm.swarm({}, master_connection)
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
        
        service_create_options = DEFAULT_SERVICE_SETTINGS
        service_create_options['TaskTemplate']['Env'] << "TEST_ENV=test"
        service_create_options["Mode"]["Replicated"]["Replicas"] = 5
        service_create_options["EndpointSpec"]["Ports"] = [{"Protocol" => "tcp", "PublishedPort" => 8181, "TargetPort" => 80}]
        service = swarm.create_service(service_create_options)

        expect(swarm.services.length).to eq 1
        
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
        worker_node.leave
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
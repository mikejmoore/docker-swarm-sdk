require 'spec_helper'
require_relative '../../../lib/docker/swarm/node'
require_relative '../../../lib/docker/swarm/swarm'
require_relative '../../../lib/docker/swarm/service'

describe Docker::Node do
  describe '#all' do
    it "Retrieves all Nodes" do

      master_ip = "192.168.40.24"
      worker_ip = "192.168.40.50"
      Docker.url = "http://#{master_ip}:2375"
      network_name = "app.1"

      master_connection = Docker::Connection.new("http://" + master_ip + ":2375", Docker.options)
      worker_connection = Docker::Connection.new("http://" + worker_ip + ":2375", Docker.options)

      begin
        begin
          puts "Cleanup: Worker node leaving swarm"
          Docker::Swarm.leave(false, worker_connection)
        rescue
        end
        begin
          puts "Cleanup: Manager node leaving swarm"
          Docker::Swarm.leave(true, master_connection)
        rescue
        end
        
        puts "Deleting network: #{network_name}"
        networks = Docker::Network.all({}, master_connection)
        networks.each do |network|
          puts "Existing network: #{network}"
          if (network.info['Name'] == network_name)
            puts "Deleting network: #{network.info['Name']}"
            network.remove()
          end
        end
        
        swarm_init_options = {
            "ListenAddr" => "0.0.0.0:2377",
            "AdvertiseAddr" => "#{master_ip}:2377",
            "ForceNewCluster" => false,
            "Spec" => {
              "Orchestration" => {},
              "Raft" => {},
              "Dispatcher" => {},
              "CAConfig" => {}
            }
          }
          
        puts "Manager node intializing swarm"
        node_id = Docker::Swarm.init(swarm_init_options, master_connection)
        
        puts "Getting info about new swarm environment"
        swarm = Docker::Swarm.swarm({}, master_connection)
        join_options = {
                "ListenAddr" => "0.0.0.0:2377",
                "AdvertiseAddr" => "#{worker_ip}:2377",
                "RemoteAddrs" => ["#{master_ip}:2377"],
                "JoinToken" => swarm.worker_join_token
              }
        puts "Worker joining swarm"
        Docker::Swarm.join(join_options, worker_connection)
        
        puts "View all nodes of swarm (2)"
        nodes = Docker::Node.all(master_connection)
        expect(nodes.length).to eq 2
        network = Docker::Network.create(network_name, opts = {}, master_connection)
        service_create_options = {
          "Name" => "nginx",
          "TaskTemplate" => {
            "ContainerSpec" => {
              "Image" => "nginx:1.11.7",
              "Mounts" => [
              ],
              "User" => "root"
            },
            "Env" => ["TEST_ENV=test"],
            # "LogDriver" => {
            #   "Name" => "json-file",
            #   "Options" => {
            #     "max-file" => "3",
            #     "max-size" => "10M"
            #   }
            # },
             "Placement" => {},
            # "Resources" => {
            #   "Limits" => {
            #     "MemoryBytes" => 104857600.0
            #   },
            #   "Reservations" => {
            #   }
            # },
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
          # "UpdateConfig" => {
          #   "Delay" => 2,
          #   "Parallelism" => 2,
          #   "FailureAction" => "pause"
          # },
      #    "Networks" => [network.id],
          "EndpointSpec" => {
            "Ports" => [
              {
                "Protocol" => "tcp",
                "PublishedPort" => 80,
                "TargetPort" => 80
              }
            ]
          },
          "Labels" => {
            "foo" => "bar"
          }
        }
        
        service = Docker::Service.create(service_create_options, master_connection)
        service.scale(20)
        service.remove()
        force = false
        Docker::Swarm.leave(force, worker_connection)
      rescue Exception => ex
        puts ex.message
        puts ex.backtrace.join("\n")
      ensure
        force = true
        Docker::Swarm.leave(force, master_connection)
      end
      
      #connection = Excon.new('http://127.0.0.1:2375/swarm/init')
      # connection = Excon.new('tcp://192.168.40.24:2375/swarm/init')
      # response = connection.post()
      # debugger


      # connection = Excon.new('tcp://127.0.0.1:2375/services')
      # response = connection.get()
      # debugger
      #
      # Docker.url = "http://127.0.0.1:2375"
      # connection = Docker::Connection.new(Docker.url, Docker.options)
      # Docker::Swarm.init({}, connection)
      # options = {}
      # Docker::Node.all(options, connection)
      # debugger
    end
  end
end
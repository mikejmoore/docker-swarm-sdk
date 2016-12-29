# docker-swarm-api

Ruby compatible API for managing Docker Swarm clusters.

MIT License

Must use Docker API Version of 1.24 or above.

This project leverages swipely/docker-api (https://github.com/swipely/docker-api), and adds Docker Swarm capability.

Warning: cannot create overlay network in Docker Engine versions less than 1.13 (which is still categoriezed as Dev, not as stable).  

Sample Usage
------------
```ruby
 # Make a connection to the Swarm manager's API.  (Assumes port 2375 exposed for API)
master_connection = Docker::Swarm::Connection.new('http://10.20.30.1:2375')

 # Manager node intializes swarm
swarm_init_options = { "ListenAddr" => "0.0.0.0:2377" }
swarm = Docker::Swarm::Swarm.init(swarm_init_options, master_connection)

 # Gather all nodes available to swarm (overlay and bridges)
nodes = swarm.nodes()
expect(nodes.length).to eq 1

 # Worker joins swarm
worker_connection = Docker::Swarm::Connection.new('http://10.20.30.2:2375')
swarm.join_worker(worker_connection)

 # Join another manager to the swarm
manager_2_connection = Docker::Swarm::Connection.new('http://10.20.30.3:2375')
swarm.join_worker(manager_2_connection)

 # Gather all nodes of swarm
nodes = swarm.nodes()

 # Create a network which connect services
network = swarm.create_network(network_name)

 # Find all networks in swarm cluster
networks = swarm.networks()

 # Create a service with 5 replicas
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

service = swarm.create_service(service_create_options)

 # Retrieve all manager nodes of swarm
manager_nodes = swarm.manager_nodes()

 # Retrieve all worker nodes (that aren't managers)
worker_nodes = swarm.worker_nodes()

 # Drain a worker node - stop hosting tasks/containers of services
worker_node = worker_nodes.first
worker_node.drain()

 # Gather all tasks (containers for service) being hosted by the swarm cluster
tasks = swarm.tasks()

 # Scale up or down the number of replicas on a service
service.scale(20)
      
 # Worker leaves the swarm - no forcing
swarm.leave(worker_node, node)

 # Manager leaves the swarm - forced because last manager needs to use 'force' to leave the issue.
swarm.leave(manager_node, true)

```

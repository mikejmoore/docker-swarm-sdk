# docker-swarm-api

Sample Usage
------------
```ruby
 # Create a Swarm cluster
master_connection = Docker::Swarm::Connection.new('http://10.20.30.1:2375')

 # Manager node intializes swarm
swarm_init_options = {
"ListenAddr" => "0.0.0.0:2377",
}
swarm = Docker::Swarm::Swarm.init(swarm_init_options, master_connection)

expect(swarm).to_not be nil

nodes = Docker::Swarm::Node.all({}, master_connection)
expect(nodes.length).to eq 1

 # Worker joins swarm
worker_connection = Docker::Swarm::Connection.new('http://10.20.30.2:2375')
swarm.join(worker_ip, worker_connection)

 # Gather all nodes of swarm
nodes = swarm.nodes

 # Create a network which connect services
network = swarm.create_network(network_name)

 # Find all networks in swarm cluster
networks = swarm.networks

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
manager_nodes = swarm.manager_nodes

 # Retrieve all worker nodes (that aren't managers)
worker_nodes = swarm.worker_nodes

 # Drain a worker node - stop hosting tasks/containers of services
worker_node = worker_nodes.first
worker_node.drain

 # Gather all tasks (containers for service) being hosted by the swarm cluster
tasks = swarm.tasks

 # Scale up or down the number of replicas on a service
service.scale(20)
      
 # Worker leaves the swarm - no forcing
swarm.leave(false, worker_connection)

 # Manager leaves the swarm - forced because manager's need to force the issue.
swarm.leave(true, master_connection)

```

require 'docker-api'

class Docker::Swarm::Service
  #include Docker::Base
  attr_reader :hash

  def initialize(swarm, hash)
    @swarm = swarm
    @hash = hash
  end
  
  def name()
    @hash['Spec']['Name']
  end

  def id()
    return @hash['ID']
  end
  
  def reload()
    s = @swarm.find_service(id())
    @hash = s.hash
    return self
  end
  
  def network_ids
    network_ids = []
    @hash['Endpoint']['VirtualIPs'].each do |network_info|
      network_ids << network_info['NetworkID']
    end
    return network_ids
  end
  
  def remove(opts = {})
    query = {}
    @swarm.connection.delete("/services/#{self.id}", query, :body => opts.to_json)
  end
  
  def update(opts)
    query = {}
    version = @hash['Version']['Index']
    response = @swarm.connection.post("/services/#{self.id}/update?version=#{version}", query, :body => opts.to_json)
  end

  def scale(count)
    @hash['Spec']['Mode']['Replicated']['Replicas'] = count
    self.update(@hash['Spec'])
  end


  def self.DEFAULT_OPTIONS
    default_service_create_options = {
        "Name" => "<<Required>>",
        "TaskTemplate" => {
          "ContainerSpec" => {
            "Image" => "<<Required>>",
            "Mounts" => [],
            "User" => "root"
          },
          "Env" => [],
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
#              "NanoCPUs" => ?
#              MemoryBytes => 
           }
          },
          "RestartPolicy" => {
            "Condition" => "on-failure",
            "Delay" => 1,
            "MaxAttempts" => 3
          }
        }, # End of TaskTemplate
        "Mode" => {
          "Replicated" => {
            "Replicas" => 1
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
    #          "Protocol" => "http",
    #          "PublishedPort" => 2881,
    #          "TargetPort" => 2881
            }
          ]
        },
        "Labels" => {
          "foo" => "bar"
        }
      }
    return default_service_create_options
  end
  
  
end
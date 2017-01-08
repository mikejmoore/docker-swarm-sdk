require 'docker-api'

class Docker::Swarm::Network 
  attr_reader :hash
  
  def initialize(swarm, hash)
    @hash = hash
    @swarm = swarm
  end
  
  def connection
    return @swarm.connection
  end
  
  def id
    return @hash['Id']
  end
  
  def name
    return @hash['Name']
  end

  def driver
    return @hash['Driver']
  end
  
  def subnets
    if (@hash['IPAM']) && (@hash['IPAM']['Config'])
      return @hash['IPAM']['Config']
    end
    return []
  end

  def remove
    if (@swarm)
      @swarm.nodes.each do |node|
        node.remove_network(self)
      end
    end
  end
  
end

# EXAMPLE INSPECT OF OVERLAY NETWORK:
# {
#         "Name": "overlay1",
#         "Id": "3eluvldbrv17xw6w39xxgg30a",
#         "Scope": "swarm",
#         "Driver": "overlay",
#         "EnableIPv6": false,
#         "IPAM": {
#             "Driver": "default",
#             "Options": null,
#             "Config": [
#                 {
#                     "Subnet": "10.0.9.0/24",
#                     "Gateway": "10.0.9.1"
#                 }
#             ]
#         },
#         "Internal": false,
#         "Containers": null,
#         "Options": {
#             "com.docker.network.driver.overlay.vxlanid_list": "257"
#         },
#         "Labels": null
#     }
    
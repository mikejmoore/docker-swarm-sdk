require 'docker-api'

class Docker::Swarm::Network < Docker::Network


  def self.find_by_name(network_name, connection)
    networks = Docker::Network.all({}, connection)
    
    networks.each do |network|
      if (network.info['Name'] == network_name)
        return network
      end
    end
    return nil
  end
end
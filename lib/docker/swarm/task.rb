# This class represents a Docker Swarm Node.
class Docker::Swarm::Task
  #include Docker::Base
  attr_reader :hash

  def initialize(swarm, hash)
    @hash = hash
    @swarm = swarm
  end

  def id
    return @hash['ID']
  end

  def image
    return @hash['Spec']['ContainerSpec']['Image']
  end

  def service_id
    @hash['ServiceID']
  end

  def service
    return @swarm.services.find { |service|
      self.service_id == service.id
    }
  end

  def node_id
    @hash['NodeID']
  end

  def node
    return @swarm.nodes.find {|n| n.id == self.node_id}
  end

  def created_at
    return DateTime.parse(@hash.first['CreatedAt'])
  end

  def status
    @hash['Status']['State'].to_sym
  end

  def status_timestamp
    return DateTime.parse(@hash['Status']['Timestamp'])
  end

  def status_message
    @hash['Status']['Message']
  end

  def networks
    all_networks = @swarm.networks
    nets = []
    self.hash['NetworksAttachments'].each do |net_hash|
      hash = net_hash['Network']
      network_id = hash['ID']
      nets << all_networks.find {|net| net.id == network_id}
    end
    return nets
  end

end

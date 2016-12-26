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


end

# This class represents a Docker Swarm Node.
class Docker::Swarm::Task
  #include Docker::Base
  attr_reader :hash

  def initialize(hash)
    @hash = hash
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
  
  def created_at
    return DateTime.parse(@hash.first['CreatedAt'])
  end
  
  def status
    @hash['Status']['State'].to_sym
  end

  # Return all of the Nodes.
  def self.all(opts = {}, conn = Docker.connection)
    raise "opts needs to be hash" if (opts.class != Hash)
    query = {}
    resp = conn.get('/tasks', query, :body => opts.to_json)
    hashes = JSON.parse(resp)
    items = []
    hashes.each do |hash|
      items << Docker::Swarm::Task.new(hash)
    end
    return items
  end

end

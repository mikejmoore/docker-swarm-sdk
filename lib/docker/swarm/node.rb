# This class represents a Docker Swarm Node.
class Docker::Swarm::Node
  #include Docker::Base
  attr_reader :hash
  AVAILABILITY = {
    active: "active",
    drain:  "drain"
  }

  def initialize(hash, connection)
    @hash = hash
    @connection = connection
    hash['Description']['Hostname']
  end
  
  def id 
    return @hash['ID']
  end
  
  def host_name
    return @hash['Description']['Hostname']
  end
  
  def role
    if (@hash['Spec']['Role'] == "worker")
      return :worker
    elsif (@hash['Spec']['Role'] == "manager")
      return :manager
    else
      raise "Couldn't determine machine role from spec: #{@hash['Spec']}"
    end
  end
  
  def availability
    return @hash['Spec']['Availability'].to_sym
  end
  
  def status
    return @hash['Status']['State']
  end
  
  def drain
    change_availability(:drain)
  end

  def activate
    change_availability(:active)
  end
  
  def change_availability(availability)
    raise "Bad availability param: #{availability}" if (!AVAILABILITY[availability])
    @hash['Spec']['Availability'] = AVAILABILITY[availability]
    query = {version: @hash['Version']['Index']}
    response = @connection.post("/nodes/#{self.id}/update", query, :body => @hash['Spec'].to_json)
  end

  # Return all of the Nodes.
  def self.all(opts = {}, conn = Docker.connection)
    raise "opts needs to be hash" if (opts.class != Hash)
    query = {}
    resp = conn.get('/nodes', query, :body => opts.to_json)
    hashes = JSON.parse(resp)
    nodes = []
    hashes.each do |node_hash|
      nodes << Docker::Swarm::Node.new(node_hash, conn)
    end
    return nodes
  end

  # private :path_for
  # private_class_method :new
end

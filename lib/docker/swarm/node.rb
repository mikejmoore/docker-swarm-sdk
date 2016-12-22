# This class represents a Docker Swarm Node.
class Docker::Swarm::Node
  include Docker::Base
  attr_reader :hash

  def initialize(hash)
    @hash = hash
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
    raise "Not Implemented"
  end

  # Return all of the Containers.
  def self.all(opts = {}, conn = Docker.connection)
    query = {}
    resp = conn.get('/nodes', query, :body => opts.to_json)
    hashes = JSON.parse(resp)
    nodes = []
    hashes.each do |node_hash|
      nodes << Docker::Node.new(node_hash)
    end
    return nodes
  end

  # private :path_for
  # private_class_method :new
end

require 'docker-api'

class Docker::Swarm::Service
  #include Docker::Base
  attr_reader :hash

  def initialize(hash, connection)
    @connection = connection
    @hash = hash
  end

  def id()
    return @hash['ID']
  end
  
  def remove(opts = {})
    query = {}
    @connection.delete("/services/#{self.id}", query, :body => opts.to_json)
  end
  
  def update(opts)
    query = {}
    version = @hash['Version']['Index']
    response = @connection.post("/services/#{self.id}/update?version=#{version}", query, :body => opts.to_json)
  end


  def scale(count)
    @hash['Spec']['Mode']['Replicated']['Replicas'] = count
    self.update(@hash['Spec'])
  end

  def self.create(opts = {}, conn = Docker.connection)
    query = {}
    response = conn.post('/services/create', query, :body => opts.to_json)
    info = JSON.parse(response)
    service_id = info['ID']
    return self.find(service_id, conn)
  end
  
  def self.find(id, conn = Docker.connection)
    query = {}
    opts = {}
    response = conn.get("/services/#{id}", query, :body => opts.to_json)
    hash = JSON.parse(response)
    return Docker::Swarm::Service.new(hash, conn)
  end
  
  
end
require 'docker-api'

class Docker::Swarm::Service
  #include Docker::Base
  attr_reader :hash

  def initialize(swarm, hash)
    @swarm = swarm
    @hash = hash
  end

  def id()
    return @hash['ID']
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

  
  
end
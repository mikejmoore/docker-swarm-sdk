# This class represents a Docker Swarm Node.
class Docker::Swarm::Swarm
  attr_reader :worker_join_token, :manager_join_token, :id, :hash

  def initialize(hash)
    @hash = hash
    @id = hash['ID']
    @worker_join_token = hash['JoinTokens']['Worker']
    @manager_join_token = hash['JoinTokens']['Manager']
  end

  # Initialize Swarm
  def self.init(opts, conn = Docker.connection)
    query = {}
    resp = conn.post('/swarm/init', query, :body => opts.to_json)
    swarm_id = Docker::Util.parse_json(resp) || {}
    return swarm_id
  end
  
  def self.leave(force, conn = Docker.connection)
    query = {}
    query['force'] = force
    resp = conn.post('/swarm/leave', query)
  end


  def self.join(opts, conn)
    query = {}
    resp = conn.post('/swarm/join', query, :body => opts.to_json)
  end

  # docker swarm join-token -q worker
  def self.swarm(opts, conn)
    query = {}
    resp = conn.get('/swarm', query, :body => opts.to_json)
    hash = JSON.parse(resp)
    obj = Docker::Swarm.new(hash)
    return obj
  end

end

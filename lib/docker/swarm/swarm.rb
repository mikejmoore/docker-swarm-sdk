require 'docker-api'

# This class represents a Docker Swarm Node.
class Docker::Swarm::Swarm
  attr_reader :worker_join_token, :manager_join_token, :id, :hash

  def initialize(hash, connection)
    @connection = connection
    @hash = hash
    @id = hash['ID']
    @worker_join_token = hash['JoinTokens']['Worker']
    @manager_join_token = hash['JoinTokens']['Manager']
    @workers = []
  end

  def join(worker_ip, worker_connection)
    query = {}
    master_ip = @connection.url.split("//").last.split(":").first
    join_options = {
            "ListenAddr" => "0.0.0.0:2377",
            "AdvertiseAddr" => "#{worker_ip}:2377",
            "RemoteAddrs" => ["#{master_ip}:2377"],
            "JoinToken" => @worker_join_token
          }
    resp = worker_connection.post('/swarm/join', query, :body => join_options.to_json)
    @workers << {address: worker_ip, connection: worker_connection}
  end

  def manager_nodes
    nodes = Docker::Swarm::Node.all({}, @connection)
    nodes.select { |node|
      node.role == :manager
    }
  end

  def worker_nodes
    nodes = Docker::Swarm::Node.all({}, @connection)
    nodes.select { |node|
      node.role == :worker
    }
  end

  def leave(force = true)
    Docker::Swarm::Swarm.leave(force, @connection)
  end

  # Initialize Swarm
  def self.init(opts, conn = Docker.connection)
    query = {}
    resp = conn.post('/swarm/init', query, :body => opts.to_json, full_response: true)
    return Docker::Swarm::Swarm.swarm(opts, conn)
  end

  # docker swarm join-token -q worker
  def self.swarm(opts, conn = Docker.connection)
    query = {}
    resp = conn.get('/swarm', query, :body => opts.to_json, expects: [200, 406], full_response: true)
    if (resp.status == 406)
      return nil
    elsif (resp.status == 200)
      hash = JSON.parse(resp.body)
      return Docker::Swarm::Swarm.new(hash, conn)
    else
      raise "Bad response: #{resp.status} #{resp.body}"
    end
  end
  
  def self.leave(force, conn = Docker.connection)
    query = {}
    query['force'] = force
    conn.post('/swarm/leave', query, expects: [200, 406])
  end
  

end

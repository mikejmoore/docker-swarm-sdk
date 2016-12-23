require 'docker-api'

# This class represents a Docker Swarm Node.
class Docker::Swarm::Swarm
  include Docker
  attr_reader :worker_join_token, :manager_join_token, :id, :hash, :node_hash

  def initialize(hash, manager_connection)
    @hash = hash
    @id = hash['ID']
    @worker_join_token = hash['JoinTokens']['Worker']
    @manager_join_token = hash['JoinTokens']['Manager']
    manager_node = nodes(manager_connection).first
    @node_hash = {}
    @node_hash[manager_node.id] = {hash: manager_node.hash, connection: manager_connection}
  end

  def join(node_connection, join_token)
    node_ids_before = nodes().collect {|n| n.id}
    query = {}
    master_ip = self.connection.url.split("//").last.split(":").first
    new_node_ip = node_connection.url.split("//").last.split(":").first
    join_options = {
            "ListenAddr" => "0.0.0.0:2377",
            "AdvertiseAddr" => "#{new_node_ip}:2377",
            "RemoteAddrs" => ["#{master_ip}:2377"],
            "JoinToken" => join_token
          }
    resp = node_connection.post('/swarm/join', query, :body => join_options.to_json, expects: [200])
    nodes.each do |node|
      if (!node_ids_before.include? node.id)
        @node_hash[node.id] = {hash: node.hash, connection: node_connection}
      end
    end
  end
  
  def connection
    @node_hash.keys.each do |node_id|
      node_info = @node_hash[node_id]
      if (node_info[:hash]['ManagerStatus'])
        return node_info[:connection]
      end
    end
    raise "No manager connection found for swarm"
  end

  def join_worker(node_connection)
    join(node_connection, @worker_join_token)
  end
  
  def join_manager(manager_connection)
    join(node_connection, @manager_join_token)
  end

  def remove
    worker_nodes.each do |node|
      leave(node, true)
    end
    manager_nodes.each do |node|
      leave(node, true)
    end
  end
  
  def tasks
    items = []
    query = {}
    opts = {}
    resp = self.connection.get('/tasks', query, :body => opts.to_json)
    hashes = JSON.parse(resp)
    items = []
    hashes.each do |hash|
      items << Swarm::Task.new(self, hash)
    end
    return items
  end

  def leave(node, force = false)
    node.connection = self.connection
    node_info = @node_hash[node.id]
    if (node_info)
      Docker::Swarm::Swarm.leave(force, node_info[:connection])
    end
  end
  
  def remove_node(worker_node)
    Swarm::Node.remove(worker_node.id, self.connection)
  end
  
  def manager_nodes
    return nodes.select { |node| node.role == :manager} || []
  end

  def worker_nodes
    return nodes.select { |node| node.role == :worker} || []
  end
  
  def networks
    networks = Docker::Network.all({}, self.connection)
  end
  
  def create_network(network_name)
    return Docker::Swarm::Network.create(network_name, opts = {}, self.connection)
  end
  
  def find_network_by_name(network_name)
    return Docker::Swarm::Network::find_by_name(network_name, self.connection)
  end
  
  # Return all of the Nodes.
  def nodes(conn = self.connection)
    opts = {}
    query = {}
    response = conn.get('/nodes', query, :body => opts.to_json, expects: [200, 406], full_response: true)
    if (response.status == 200)
      hashes = JSON.parse(response.body)
      nodes = []
      hashes.each do |node_hash|
        nodes << Docker::Swarm::Node.new(self, node_hash)
      end
      return nodes || []
    else
      return []
    end
  end

  def create_service(opts = {})
    query = {}
    response = self.connection.post('/services/create', query, :body => opts.to_json)
    info = JSON.parse(response)
    service_id = info['ID']
    return self.find_service(service_id)
  end
  
  def find_service(id)
    query = {}
    opts = {}
    response = self.connection.get("/services/#{id}", query, :body => opts.to_json)
    hash = JSON.parse(response)
    return Docker::Swarm::Service.new(self, hash)
  end


  # Initialize Swarm
  def self.init(opts, connection)
    query = {}
    resp = connection.post('/swarm/init', query, :body => opts.to_json, full_response: true)
    return Docker::Swarm::Swarm.swarm(opts, connection)
  end

  # docker swarm join-token -q worker
  def self.swarm(opts, connection)
    query = {}
    resp = connection.get('/swarm', query, :body => opts.to_json, expects: [200, 406], full_response: true)
    if (resp.status == 406)
      return nil
    elsif (resp.status == 200)
      hash = JSON.parse(resp.body)
      return Docker::Swarm::Swarm.new(hash, connection)
    else
      raise "Bad response: #{resp.status} #{resp.body}"
    end
  end
  
  def self.leave(force, connection)
    query = {}
    query['force'] = force
    connection.post('/swarm/leave', query, expects: [200, 406])
  end
  
  

end

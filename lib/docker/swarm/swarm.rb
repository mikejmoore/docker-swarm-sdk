require 'docker-api'
require 'resolv'


# This class represents a Docker Swarm Node.
class Docker::Swarm::Swarm
  include Docker
  attr_reader :worker_join_token, :manager_join_token, :id, :hash, :node_hash

  def initialize(hash, manager_connection, options = {})
    @hash = hash
#    @manager_connection = manager_connection
    @id = hash['ID']
    @worker_join_token = hash['JoinTokens']['Worker']
    @manager_join_token = hash['JoinTokens']['Manager']
    @node_hash = {}
    @manager_connection = manager_connection
    nodes.each do |node|
      node_connection = nil
      docker_port = options[:docker_api_port] || 2375
      if (node.hash['ManagerStatus'])
        ip_address = node.hash['ManagerStatus']['Addr'].split(":").first
        manager_ip_address = @manager_connection.url.split('//').last.split(':').first
        if (ip_address == manager_ip_address)
          node.connection = @manager_connection
        else
          node.connection = Docker::Swarm::Connection.new("tcp://#{ip_address}:#{docker_port}")
        end
      else
        ip_address = nil
        begin
          ip_address = Resolv::DNS.new.getaddress(node.host_name())
        rescue
          ip_address = Resolv::Hosts.new.getaddress(node.host_name())
          if (!ip_address)
            host_addresses = options[:host_addresses]
            ip_address = host_addresses[node.host_name]
          end
        end
        node.connection = Docker::Swarm::Connection.new("tcp://#{ip_address}:#{docker_port}")
      end
      @node_hash[node.id] = {hash: node.hash, connection: node.connection}
      
    end
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
    new_node = nil
    resp = node_connection.post('/swarm/join', query, :body => join_options.to_json, expects: [200])
    nodes.each do |node|
      if (!node_ids_before.include? node.id)
        new_node = node
        @node_hash[node.id] = {hash: node.hash, connection: node_connection}
      end
    end
    return new_node
  end
  
  def connection
    @node_hash.keys.each do |node_id|
      node_info = @node_hash[node_id]
      if (node_info[:hash]['ManagerStatus'])
        return node_info[:connection]
      end
    end
    return @manager_connection
  end

  def join_worker(node_connection)
    join(node_connection, @worker_join_token)
  end
  
  def join_manager(manager_connection)
    join(node_connection, @manager_join_token)
  end

  def remove
    services().each do |service|
      service.remove()
    end
    
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
    all_networks = []
    response = connection.get("/networks", {}, full_response: true)
    if (response.status == 200)
      hashes = JSON.parse(response.body)
      hashes.each do |hash|
        all_networks << Docker::Swarm::Network.new(self, hash)
      end
    else
      raise "Error finding netw"
    end
    return all_networks
  end
  
  def create_network(network_name, options = {})
    defaults = {
        "Name" => network_name,
        "CheckDuplicate" => true,
#        "Driver" => "bridge",
        "Driver" => "overlay",
        "EnableIPv6" => false,
#         "IPAM" => {
#           "Driver" => "default",
#           "Config" => [
#             {
#              "Subnet" => "172.20.0.0/16",
#              "IPRange" => "172.20.10.0/24",
#              "Gateway" => "172.20.10.11"
#             }
#           ],
#           "Options" => {
# #            "foo" => "bar"
#           }
#          },
        "Internal" => false,
        "Options" => {
            "com.docker.network.driver.overlay.vxlanid_list" => "257"
        },
        "Labels" => {
          # "com.example.some-label": "some-value",
          # "com.example.some-other-label": "some-other-value"
        }
      }
      opts = defaults.merge(options)
      response = connection.post('/networks/create', {},  body: opts.to_json, expects: [200, 201, 500], full_response: true)
      if (response.status <= 201)
        hash = JSON.parse(response.body)
        response = connection.get("/networks/#{hash['Id']}", {}, expects: [200, 201], full_response: true)
        hash = Docker::Util.parse_json(response.body)
        network = Docker::Swarm::Network.new(self, hash)
        return network
      else
        raise "Error creating network: HTTP-#{response.status} - #{response.body}"
      end
  end
  
  def find_network_by_name(network_name)
    networks.each do |network|
      if (network.name == network_name)
        return network
      end
    end
    return nil
  end
  
  # Return all of the Nodes.
  def nodes
    opts = {}
    query = {}
    response = self.connection.get('/nodes', query, :body => opts.to_json, expects: [200, 406], full_response: true)
    if (response.status == 200)
      hashes = JSON.parse(response.body)
      nodes = []
      hashes.each do |node_hash|
        node  = Docker::Swarm::Node.new(self, node_hash)
        nodes << node
      end
      return nodes || []
    else
      return []
    end
  end

  def create_service(opts = {})
    query = {}
    response = self.connection.post('/services/create', query, :body => opts.to_json, expects: [201, 500], full_response: true)
    if (response.status <= 201)
      info = JSON.parse(response.body)
      service_id = info['ID']
      return self.find_service(service_id)
    else
      raise "Error creating service:  HTTP-#{response.status}  #{response.body}"
    end
    return nil
  end
  
  def find_service(id)
    query = {}
    opts = {}
    response = self.connection.get("/services/#{id}", query, :body => opts.to_json)
    hash = JSON.parse(response)
    return Docker::Swarm::Service.new(self, hash)
  end
  
  def find_service_with_name(name)
    services.each do |service|
      return service if (service.name == name)
    end
    return nil
  end
  
  def services
    items = []
    query = {}
    opts = {}
    response = self.connection.get("/services", query, :body => opts.to_json)
    hashes = JSON.parse(response)
    hashes.each do |hash|
      items << Docker::Swarm::Service.new(self, hash)
    end
    return items
  end
  
  def discover_nodes
    # {discover_nodes: true, worker_docker_port: 2375}
    
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
    response = connection.post('/swarm/leave', query, expects: [200, 406, 500], full_response: true)
    if (response.status == 500)
      raise "Error leaving: #{response.body}  HTTP-#{response.status}"
    end
  end
  
  def self.find(connection, options = {})
    query = {}
    response = connection.get('/swarm', query, expects: [200, 406], full_response: true)
    if (response.status == 200)
      swarm = Docker::Swarm::Swarm.new(JSON.parse(response.body), connection, options)
      return swarm
    elsif (response.status == 406)
      return nil
    else 
      raise "Error finding swarm: HTTP-#{response.status} #{response.body}"
    end
  end
  

end

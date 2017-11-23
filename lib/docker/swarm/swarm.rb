require 'docker-api'
require 'resolv'


# This class represents a Docker Swarm Node.
class Docker::Swarm::Swarm
  include Docker
  attr_reader :node_ip, :manager_ip, :worker_join_token, :manager_join_token, :id, :hash, :node_hash

  def store_manager(manager_connection, listen_address_and_port)
    node = nodes.find {|n|
      (n.hash['ManagerStatus']) && (n.hash['ManagerStatus']['Leader'] == true) && (n.hash['ManagerStatus']['Addr'] == listen_address_and_port)
    }
    raise "Node not found for: #{listen_address}" if (!node)
    @node_hash[node.id] = {hash: node.hash, connection: manager_connection}
  end

  def update_data(hash)
    @hash = hash
  end

  def socket_connection(node_connection)
    node_connection.url.include?('unix:///')
  end

  def join(node_connection, node_ip = nil, manager_ip = nil, join_token = nil, listen_address = "0.0.0.0:2377")
    node_ids_before = []
    query = {}

    unless socket_connection(node_connection)
      node_ids_before = nodes().collect {|n| n.id}
      node_ip = node_connection.url.split("//").last.split(":").first
      manager_ip = self.connection.url.split("//").last.split(":").first
    end

    join_options = {
            "ListenAddr" => "#{listen_address}",
            "AdvertiseAddr" => "#{node_ip}:2377",
            "RemoteAddrs" => ["#{manager_ip}:2377"],
            "JoinToken" => join_token
          }

    new_node = nil
    response = node_connection.post('/swarm/join', query, :body => join_options.to_json, expects: [200, 406, 500], full_response: true)

    if (response.status == 200)
      nodes.each do |node|
        if (!node_ids_before.include? node.id)
          new_node = node
          @node_hash[node.id] = {hash: node.hash, connection: node_connection}
        end
      end unless socket_connection(node_connection)
      return new_node
    elsif (response.status == 406)
      puts "Node is already part of a swarm - maybe this swarm, maybe another swarm."
      return nil
    else
      raise "Error joining (#{node_connection}):  HTTP-#{response.status}  #{response.body}"
    end
  end

  def join_worker(node_connection, listen_address = "0.0.0.0:2377")
    join(node_connection, @node_ip, @manager_ip, @worker_join_token)
  end

  def join_manager(node_connection, listen_address = "0.0.0.0:2377")
    join(node_connection, @node_ip, @manager_ip, @manager_join_token, listen_address)
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

  def create_network(options)
    response = connection.post('/networks/create', {},  body: options.to_json, expects: [200, 201, 500], full_response: true)
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

  def create_network_overlay(network_name)
    subnet_16_parts = [10, 10, 0, 0]
    max_vxlanid = 200

    # Sometimes nodes have leftover networks not on other nodes, that have subnets that can't be duplicated in
    # the new overlay network.
    nodes.each do |node|
      node.networks.each do |network|
        if (network.driver == 'overlay')
          if (network.hash['Options'])
            vxlanid = network.hash['Options']["com.docker.network.driver.overlay.vxlanid_list"]
            if (vxlanid) && (vxlanid.to_i > max_vxlanid)
              max_vxlanid = vxlanid.to_i
            end
          end
        end

        # Make sure our new network doesn't duplicate subnet of other network.
        if (network.hash['IPAM']) && (network.hash['IPAM']['Config'])
          network.hash['IPAM']['Config'].each do |subnet_config|
            if (subnet_config['Subnet'])
              subnet = subnet_config['Subnet']
              subnet = subnet.split(".")
              if (subnet[0] == '10') && (subnet[1] == '255')
              else
                if (subnet[0].to_i == subnet_16_parts[0])
                  if (subnet[1].to_i >= subnet_16_parts[1])
                    subnet_16_parts[1] = subnet[1].to_i + 1
                    if (subnet_16_parts[1] >= 255)
                      raise "Ran out of subnets"
                    end
                  end
                end
              end
  #            subnet_config['Gateway']
            end
          end
        end
      end
    end


    options = {
        "Name" => network_name,
        "CheckDuplicate" => true,
        "Driver" => "overlay",
        "EnableIPv6" => false,
        "IPAM" => {
          "Driver" => "default",
          "Config" => [
            {
             "Subnet" => "#{subnet_16_parts.join(".")}/16",
             "Gateway"=> "#{subnet_16_parts[0, 3].join('.')}.1"
           }
          ],
           "Options" => {
           }
        },
        "Internal" => false,
        "Options" => {
          "com.docker.network.driver.overlay.vxlanid_list" => (max_vxlanid + 1).to_s
        },
        "Labels" => {
          # "com.example.some-label": "some-value",
          # "com.example.some-other-label": "some-other-value"
        }
      }
      create_network(options)
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
    response = self.connection.post('/services/create', query, :body => opts.to_json, expects: [201, 404, 409, 500], full_response: true)
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

  def find_service_by_name(name)
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


  # Initialize Swarm
  def self.init(opts, connection)
    query = {}
    resp = connection.post('/swarm/init', query, :body => opts.to_json, full_response: true, expects: [200, 404, 406, 500])
    if (resp.status == 200)
      swarm = Docker::Swarm::Swarm.swarm(connection, opts)
      manager_node = swarm.nodes.find {|n|
        (n.hash['ManagerStatus']) && (n.hash['ManagerStatus']['Leader'] == true)
      }
      listen_address = manager_node.hash['ManagerStatus']['Addr']
      swarm.store_manager(connection, listen_address)
      return swarm
    else
      raise "Bad response: #{resp.status} #{resp.body}"
    end
  end

  # docker swarm join-token -q worker
  def self.swarm(connection, options = {})
    query = {}
    resp = connection.get('/swarm', query, :body => options.to_json, expects: [200, 404, 406], full_response: true)
    if (resp.status == 406) || (resp.status == 404)
      return nil
    elsif (resp.status == 200)
      hash = JSON.parse(resp.body)
      swarm = self.find_swarm_for_id(hash['ID'])
      if (swarm)
        swarm.update_data(hash)
      else
        swarm = Docker::Swarm::Swarm.new(hash, connection, options)
      end
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
    response = connection.get('/swarm', query, expects: [200, 404, 406], full_response: true)
    if (response.status == 200)
      hash = JSON.parse(response.body)
      swarm = self.find_swarm_for_id(hash['ID'])
      if (swarm)
        swarm.update_data(hash)
      else
        swarm = Docker::Swarm::Swarm.new(hash, connection, options)
      end
      manager_node = swarm.nodes.find {|n|
        (n.hash['ManagerStatus']) && (n.hash['ManagerStatus']['Leader'] == true)
      }
      listen_address = manager_node.hash['ManagerStatus']['Addr']
      swarm.store_manager(connection, listen_address)
      return swarm
    elsif (response.status > 200)
      return nil
    else
      raise "Error finding swarm: HTTP-#{response.status} #{response.body}"
    end
  end


 private
 @@swarms = {}

 def self.find_swarm_for_id(swarm_id)
   return @@swarms[swarm_id]
 end

 def initialize(hash, manager_connection = nil, options = {})
   @hash = hash
   @id = hash['ID']
   @node_ip = hash['node_ip']
   @manager_ip = hash['manager_ip']
   @worker_join_token = hash['JoinTokens']['Worker']
   @manager_join_token = hash['JoinTokens']['Manager']
   @node_hash = {}
   @manager_connection = manager_connection
   @@swarms[@id] = self
 end




end

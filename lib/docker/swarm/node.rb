# This class represents a Docker Swarm Node.
class Docker::Swarm::Node
  #include Docker::Base
  attr_reader :hash
  attr_accessor :connection
  AVAILABILITY = {
    active: "active",
    drain:  "drain"
  }

  def initialize(swarm, hash)
    @hash = hash
    @swarm = swarm
  end
  
  def refresh
    query = {}
    response = @swarm.connection.get("/nodes/#{id}", query, expects: [200])
    @hash = JSON.parse(response)
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
  
  def remove
    Docker::Swarm::Node.remove(id(), @connection)
  end
  
  def change_availability(availability)
    raise "Bad availability param: #{availability}" if (!AVAILABILITY[availability])
    @hash['Spec']['Availability'] = AVAILABILITY[availability]
    query = {version: @hash['Version']['Index']}
    response = @swarm.connection.post("/nodes/#{self.id}/update", query, :body => @hash['Spec'].to_json)
  end
  
  def remove
    query = {}
    response = @swarm.connection.delete("/nodes/#{self.id}", query, expects: [200, 406])
  end
  
  
end

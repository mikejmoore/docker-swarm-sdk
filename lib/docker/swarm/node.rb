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
  
  def drain(opts = {})
    change_availability(:drain)
    if (opts[:wait_for_drain])
      opts[:wait_seconds]
      while (running_tasks.length > 0)
        puts "Waiting for node (#{host_name}) to drain.  Still has #{running_tasks.length} tasks running."
      end
    end
  end
  
  def running_tasks
    return tasks.select {|t| t.status == 'running'}
  end
  
  def tasks
    return @swarm.tasks.select {|t| 
      (t.node != nil) && (t.node.id == self.id)
    }
  end

  def activate
    change_availability(:active)
  end
  
  def remove
    leave(true)
    refresh
    start_time = Time.now
    while (self.status != 'down')
      refresh
      raise "Node not down 60 seconds after leaving swarm: #{self.host_name}" if (Time.now.to_i - start_time.to_i > 60)
    end
    Docker::Swarm::Node.remove(self.id, @swarm.connection)
  end
  
  def leave(force = true)
    drain(wait_for_drain: true, wait_seconds: 60)
    # change_availability(:active)
    @swarm.leave(self, force)
  end
  
  def change_availability(new_availability)
    raise "Bad availability param: #{availability}" if (!AVAILABILITY[availability])
    refresh
    if (self.availability != new_availability)
      @hash['Spec']['Availability'] = AVAILABILITY[new_availability]
      query = {version: @hash['Version']['Index']}
      response = @swarm.connection.post("/nodes/#{self.id}/update", query, :body => @hash['Spec'].to_json, expects: [200, 500], full_response: true)
      if (response.status != 200)
        raise "Error changing node availability: #{response.body} HTTP-#{response.status}"
      end
    end
  end
  
  def self.remove(node_id, connection)
    query = {}
    response = connection.delete("/nodes/#{node_id}", query, expects: [200, 406, 500], full_response: true)
    if (response.status != 200)
      raise "Error deleting node: #{response.body}"
    end
  end
  
  
end

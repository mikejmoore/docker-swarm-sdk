# This class represents a Connection to a Docker server. The Connection is
# immutable in that once the url and options is set they cannot be changed.
class Docker::Swarm::Connection < Docker::Connection
  
  def initialize(url, opts = {})
    super(url, opts)
  end
  

  # Send a request to the server with the `
  def request(*args, &block)
    request = compile_request_params(*args, &block)
    log_request(request)
    if (args.last[:full_response] == true)
      resource.request(request)
    else
      resource.request(request).body
    end
  end

end

# This class represents a Connection to a Docker server. The Connection is
# immutable in that once the url and options is set they cannot be changed.
class Docker::Swarm::Connection < Docker::Connection
  
  def initialize(url, opts = {})
    super(url, opts)
  end
  
  #
  # # The actual client that sends HTTP methods to the Docker server. This value
  # # is not cached, since doing so may cause socket errors after bad requests.
  # def resource
  #   Excon.new(url, options)
  # end
  # private :resource

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

  # def log_request(request)
  #   if Docker.logger
  #     Docker.logger.debug(
  #       [request[:method], request[:path], request[:query], request[:body]]
  #     )
  #   end
  # end

#   # Delegate all HTTP methods to the #request.
#   [:get, :put, :post, :delete].each do |method|
#     define_method(method) { |*args, &block| request(method, *args, &block) }
#   end
#
#   def to_s
#     "Docker::Connection { :url => #{url}, :options => #{options} }"
#   end
#
# private
#   # Given an HTTP method, path, optional query, extra options, and block,
#   # compiles a request.
#   def compile_request_params(http_method, path, query = nil, opts = nil, &block)
#     query ||= {}
#     opts ||= {}
#     headers = opts.delete(:headers) || {}
#     content_type = opts[:body].nil? ?  'text/plain' : 'application/json'
#     user_agent = "Swipely/Docker-API #{Docker::VERSION}"
#     {
#       :method        => http_method,
#       :path          => "/v#{Docker::API_VERSION}#{path}",
#       :query         => query,
#       :headers       => { 'Content-Type' => content_type,
#                           'User-Agent'   => user_agent,
#                         }.merge(headers),
#       :expects       => (200..204).to_a << 301 << 304,
#       :idempotent    => http_method == :get,
#       :request_block => block,
#     }.merge(opts).reject { |_, v| v.nil? }
#   end
end

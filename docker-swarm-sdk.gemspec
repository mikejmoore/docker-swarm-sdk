# -*- encoding: utf-8 -*-

# To build:
# gem build docker-swarm-api.gemspec

require File.expand_path('../lib/docker/swarm/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ['Mike Moore']
  gem.email         = 'm.moore.denver@gmail.com'
  gem.description   = 'API for creating container clusters and services using Docker Swarm.  Includes service, node, task management'
  gem.summary       = 'Ruby API for Docker Swarm'
  gem.homepage      = 'https://github.com/mikejmoore/docker-swarm-api'
  gem.license       = 'MIT'
  gem.files         = `git ls-files lib README.md LICENSE`.split($\)
  gem.name          = 'docker-swarm-api'
  gem.version       = Docker::Swarm::VERSION
  gem.add_dependency 'json'
  gem.add_runtime_dependency 'docker-api', '>= 1.33.1'
  gem.add_runtime_dependency 'retry_block', '>= 1.2.0'
  gem.add_development_dependency 'byebug', '~> 6.0'
  gem.add_development_dependency 'rake', '~> 12.0'
  gem.add_development_dependency 'rspec', '~> 3.0'
  gem.add_development_dependency 'rspec-its', '1.2'
  gem.add_development_dependency 'pry', '~> 0.10.4'
  gem.add_development_dependency 'single_cov', '~> 0.5.8'
  gem.add_development_dependency 'parallel', '~> 1.10'
end

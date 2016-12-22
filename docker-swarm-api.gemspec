# -*- encoding: utf-8 -*-
require File.expand_path('../lib/docker/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ['Mike Moore / Rogue Wave Software']
  gem.email         = 'mike.moore@roguewave.com'
  gem.description   = gem.summary = 'A simple REST client for the Docker Remote API'
  gem.homepage      = 'https://github.com/maxerly/docker-swarm-api'
  gem.license       = 'MIT'
  gem.files         = `git ls-files lib README.md LICENSE`.split($\)
  gem.name          = 'docker-swarm-api'
  gem.version       = Docker::VERSION
#  gem.add_dependency 'excon', '>= 0.38.0'
  gem.add_dependency 'json'
  gem.add_dependency 'docker-api', '>= 1.33.1'
  gem.add_development_dependency 'byebug', '~> 6.0'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec', '~> 3.0'
  gem.add_development_dependency 'rspec-its'
#  gem.add_development_dependency 'cane'
  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'single_cov'
#  gem.add_development_dependency 'webmock'
  gem.add_development_dependency 'parallel'
end

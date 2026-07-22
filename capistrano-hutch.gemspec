# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'capistrano-hutch'
  spec.version = '0.1.0'
  spec.authors = ['allen12921']
  spec.email = ['allen12921@users.noreply.github.com']
  spec.description = 'Hutch RabbitMQ consumer integration for Capistrano 3'
  spec.summary = 'Systemd-managed Hutch deploys for Capistrano, modeled on capistrano3-puma'
  spec.homepage = 'https://github.com/allen12921/capistrano-hutch'
  spec.license = 'MIT'

  spec.required_ruby_version = Gem::Requirement.new(">= 2.7")

  spec.files = Dir.glob('lib/**/*') + %w(README.md LICENSE.txt)
  spec.require_paths = ['lib']

  spec.add_dependency 'capistrano', '~> 3.7'
  spec.add_dependency 'capistrano-bundler'
  spec.add_dependency 'hutch', '>= 1.0'
end

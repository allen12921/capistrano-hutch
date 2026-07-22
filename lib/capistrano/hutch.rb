require 'erb'
require 'stringio'
require 'capistrano/bundler'
require 'capistrano/plugin'

module Capistrano
  module HutchCommon
    def hutch_switch_user(role, &block)
      user = hutch_user(role)
      if user == role.user
        yield
      else
        backend.as(user, &block)
      end
    end

    def hutch_user(role)
      properties = role.properties
      return role.user unless properties

      properties.fetch(:hutch_user) ||
        fetch(:hutch_user, nil) ||
        properties.fetch(:run_as) || # global property across multiple capistrano gems
        role.user
    end

    # Hutch has no built-in sd_notify support (unlike Puma 6.1+), so the
    # unit is always a plain long-running process, not "notify".
    def service_unit_type
      fetch(:hutch_service_unit_type, 'simple')
    end

    def compiled_template_hutch(from, role)
      @role = role
      file = [
        "lib/capistrano/templates/#{from}-#{role.hostname}-#{fetch(:stage)}.rb",
        "lib/capistrano/templates/#{from}-#{role.hostname}.rb",
        "lib/capistrano/templates/#{from}-#{fetch(:stage)}.rb",
        "lib/capistrano/templates/#{from}.rb.erb",
        "lib/capistrano/templates/#{from}.rb",
        "lib/capistrano/templates/#{from}.erb",
        "config/deploy/templates/#{from}.rb.erb",
        "config/deploy/templates/#{from}.rb",
        "config/deploy/templates/#{from}.erb",
        File.expand_path("../templates/#{from}.erb", __FILE__),
        File.expand_path("../templates/#{from}.rb.erb", __FILE__)
      ].detect { |path| File.file?(path) }
      erb = File.read(file)
      StringIO.new(ERB.new(erb, trim_mode: '-').result(binding))
    end

    def template_hutch(from, to, role)
      backend.upload! compiled_template_hutch(from, role), to
    end

    def expanded_bundle_command
      backend.capture(:echo, SSHKit.config.command_map[:bundle]).strip
    end

    # Builds the trailing CLI args passed to `hutch`, e.g.:
    #   --require ./config/environment --config config/hutch.yml --foo bar
    def hutch_cli_args
      args = []
      args << "--require #{fetch(:hutch_require)}" if fetch(:hutch_require)
      args << "--config #{fetch(:hutch_config)}" if fetch(:hutch_config)
      args.concat(Array(fetch(:hutch_options)))
      args.join(' ')
    end
  end

  class Hutch < Capistrano::Plugin
    include HutchCommon

    def set_defaults
      # Matches the role name already used by hand-rolled Capistrano tasks
      # in the wild (lib/capistrano/tasks/hutch.rake-style setups), so this
      # plugin is a drop-in replacement without renaming existing roles.
      set_if_empty :hutch_role, -> { :app }
      set_if_empty :hutch_env, -> { fetch(:rack_env, fetch(:rails_env, fetch(:rake_env, fetch(:stage)))) }
      set_if_empty :hutch_require, nil
      set_if_empty :hutch_config, nil
      set_if_empty :hutch_options, []
      set_if_empty :hutch_log, -> { File.join(shared_path, 'log', 'hutch.log') }

      # Chruby, Rbenv and RVM integration
      append :chruby_map_bins, 'hutch' if fetch(:chruby_map_bins)
      append :rbenv_map_bins, 'hutch' if fetch(:rbenv_map_bins)
      append :rvm_map_bins, 'hutch' if fetch(:rvm_map_bins)

      # Bundler integration
      append :bundle_bins, 'hutch'
    end
  end
end

require 'capistrano/hutch/systemd'

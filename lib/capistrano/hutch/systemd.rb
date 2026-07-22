module Capistrano
  class Hutch::Systemd < Capistrano::Plugin
    include HutchCommon

    def register_hooks
      # The actual on/off switch is read at task-run time (see hutch:smart_restart),
      # not here — plugin hooks register before stage-specific config/deploy/*.rb
      # files override `hutch_default_hooks`, so gating the hook itself here would
      # silently ignore per-stage overrides.
      after 'deploy:published', 'hutch:smart_restart'
    end

    def define_tasks
      eval_rakefile File.expand_path('../../tasks/systemd.rake', __FILE__)
    end

    def set_defaults
      set_if_empty :hutch_default_hooks, true

      set_if_empty :hutch_systemctl_bin, -> { fetch(:systemctl_bin, '/bin/systemctl') }
      set_if_empty :hutch_service_unit_name, -> { "#{fetch(:application)}_hutch_#{fetch(:stage)}" }
      set_if_empty :hutch_systemd_watchdog_sec, nil # Hutch has no sd_notify support; leave unset

      set_if_empty :hutch_service_unit_env_files, -> { fetch(:service_unit_env_files, []) }
      set_if_empty :hutch_service_unit_env_vars, -> { fetch(:service_unit_env_vars, []) }
      set_if_empty :hutch_service_unit_props, -> { fetch(:service_unit_props, []) }

      set_if_empty :hutch_systemctl_user, -> { fetch(:systemctl_user, :user) }
      set_if_empty :hutch_enable_lingering, -> { fetch(:hutch_systemctl_user) != :system }
      set_if_empty :hutch_lingering_user, -> { fetch(:lingering_user, fetch(:user)) }

      # How long systemd waits after TERM before SIGKILL. Hutch drains
      # in-flight messages on TERM/INT, so give it real time to finish —
      # this should be >= your longest expected message-handler runtime.
      set_if_empty :hutch_stop_timeout_sec, 30
    end

    def fetch_systemd_unit_path
      if fetch(:hutch_systemctl_user) == :system
        "/etc/systemd/system/"
      else
        home_dir = backend.capture :pwd
        File.join(home_dir, ".config", "systemd", "user")
      end
    end

    def systemd_command(*args)
      command = [fetch(:hutch_systemctl_bin)]

      unless fetch(:hutch_systemctl_user) == :system
        command << "--user"
      end

      command + args
    end

    def sudo_if_needed(*command)
      if fetch(:hutch_systemctl_user) == :system
        backend.sudo command.map(&:to_s).join(" ")
      else
        backend.execute(*command)
      end
    end

    def execute_systemd(*args)
      sudo_if_needed(*systemd_command(*args))
    end
  end
end

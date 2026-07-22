# frozen_string_literal: true

git_plugin = self

namespace :hutch do
  desc 'Install Hutch systemd service'
  task :install do
    on roles(fetch(:hutch_role)) do |role|
      git_plugin.template_hutch(
        "hutch.service",
        "#{fetch(:tmp_dir)}/#{fetch(:hutch_service_unit_name)}.service",
        role
      )

      systemd_path = fetch(:hutch_systemd_conf_dir, git_plugin.fetch_systemd_unit_path)
      unit_file = "#{fetch(:hutch_service_unit_name)}.service"

      if fetch(:hutch_systemctl_user) == :system
        sudo "mv #{fetch(:tmp_dir)}/#{unit_file} #{systemd_path}"
      else
        execute :mkdir, "-p", systemd_path
        execute :mv, "#{fetch(:tmp_dir)}/#{unit_file}", systemd_path
      end

      # Reload systemd
      git_plugin.execute_systemd("daemon-reload")
    end

    # Outside the per-host `on` block above, and only once: `invoke` runs a
    # Rake task at most once per process, but `hutch:enable` itself targets
    # every host in hutch_role. Calling it from inside the loop would fire
    # on the first host's turn — before later hosts have their unit file in
    # place — and be a silent no-op for every subsequent host.
    invoke "hutch:enable"
  end

  desc 'Uninstall Hutch systemd service'
  task :uninstall do
    invoke 'hutch:disable'
    on roles(fetch(:hutch_role)) do
      systemd_path = fetch(:hutch_systemd_conf_dir, git_plugin.fetch_systemd_unit_path)
      if fetch(:hutch_systemctl_user) == :system
        sudo "rm -f #{systemd_path}/#{fetch(:hutch_service_unit_name)}*"
      else
        execute :rm, "-f", "#{systemd_path}/#{fetch(:hutch_service_unit_name)}*"
      end
      git_plugin.execute_systemd("daemon-reload")
    end
  end

  desc 'Enable Hutch systemd service'
  task :enable do
    on roles(fetch(:hutch_role)) do
      git_plugin.execute_systemd("enable", fetch(:hutch_service_unit_name))

      if fetch(:hutch_systemctl_user) != :system && fetch(:hutch_enable_lingering)
        sudo "loginctl enable-linger #{fetch(:hutch_lingering_user)}"
      end
    end
  end

  desc 'Disable Hutch systemd service'
  task :disable do
    on roles(fetch(:hutch_role)) do
      git_plugin.execute_systemd("disable", fetch(:hutch_service_unit_name))
    end
  end

  desc 'Start Hutch service via systemd'
  task :start do
    on roles(fetch(:hutch_role)) do
      git_plugin.execute_systemd("start", fetch(:hutch_service_unit_name))
    end
  end

  desc 'Stop Hutch service via systemd'
  task :stop do
    on roles(fetch(:hutch_role)) do
      git_plugin.execute_systemd("stop", fetch(:hutch_service_unit_name))
    end
  end

  desc 'Restart Hutch service via systemd'
  task :restart do
    on roles(fetch(:hutch_role)) do
      git_plugin.execute_systemd("restart", fetch(:hutch_service_unit_name))
    end
  end

  # Hutch is a single consumer process with no phased/zero-downtime restart
  # concept (unlike Puma's worker fork model) — "reload" is a plain restart.
  # Kept as a separate task only so ops muscle memory ported from Puma
  # (`cap production puma:reload`) has a matching Hutch command.
  desc 'Reload Hutch service via systemd (alias for restart)'
  task :reload do
    invoke 'hutch:restart'
  end

  desc 'Restarts Hutch service via systemd, honoring hutch_default_hooks'
  task :smart_restart do
    next unless fetch(:hutch_default_hooks, true)

    invoke 'hutch:restart'
  end

  desc 'Get Hutch service status via systemd'
  task :status do
    on roles(fetch(:hutch_role)) do
      git_plugin.execute_systemd("status", fetch(:hutch_service_unit_name))
    end
  end
end

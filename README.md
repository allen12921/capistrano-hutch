# Capistrano::Hutch

[Hutch](https://github.com/gocardless/hutch) integration for Capistrano — systemd service management for RabbitMQ consumer processes, modeled directly on [capistrano3-puma](https://github.com/seuros/capistrano-puma)'s plugin architecture.

Hutch is a single long-running consumer process, not a forking cluster like Puma, so this gem is deliberately smaller: no socket/bind handling, no phased/zero-downtime restart (there's nothing to hand off between old and new workers — a deploy just restarts the one process), no `sd_notify` support (Hutch doesn't implement it, unlike Puma 6.1+). `hutch:reload` exists purely as a restart alias for ops muscle memory coming from Puma.

## Installation

Add this line to your application's Gemfile:

    gem 'capistrano-hutch', github: "allen12921/capistrano-hutch"

And then execute:

    $ bundle

## Usage

```ruby
# Capfile

require 'capistrano/hutch'
install_plugin Capistrano::Hutch
install_plugin Capistrano::Hutch::Systemd
```

To make it work with rvm, rbenv or chruby, install the plugin after the corresponding library inclusion:

```ruby
# Capfile

require 'capistrano/rbenv'
require 'capistrano/hutch'
install_plugin Capistrano::Hutch
install_plugin Capistrano::Hutch::Systemd
```

### Config

| Setting | Default | Notes |
|---|---|---|
| `hutch_role` | `:app` | Role(s) that run the Hutch consumer. Override per stage if you dedicate specific hosts to it. |
| `hutch_env` | `rack_env`/`rails_env`/`stage` | Passed to the process as `RACK_ENV`/`RAILS_ENV`. |
| `hutch_require` | `nil` | Passed as `--require <value>` to `hutch`, e.g. `./config/environment` to boot a Rails app and autoload consumers. |
| `hutch_config` | `nil` | Passed as `--config <value>` if you use a `hutch.yml`-style config file instead of/alongside env vars. |
| `hutch_options` | `[]` | Extra raw CLI args appended verbatim, e.g. `['--mq-host', 'rabbit.internal']`. |
| `hutch_log` | `shared_path/log/hutch.log` | Set to `"journal"` to let systemd/journald capture stdout+stderr instead of a file. |
| `hutch_default_hooks` | `true` | Set `false` on a stage to skip the automatic restart-on-deploy (e.g. a stage whose `hutch_role` hosts don't actually run a consumer). Checked at task-run time, so per-stage overrides in `config/deploy/<stage>.rb` are honored correctly. |
| `hutch_stop_timeout_sec` | `30` | How long systemd waits after `SIGTERM` before `SIGKILL`. Hutch drains in-flight messages on TERM — set this above your slowest consumer's expected handling time. |
| `hutch_systemctl_user` | `:user` | `:system` installs into `/etc/systemd/system` via sudo instead of a user-space unit. |
| `hutch_service_unit_name` | `#{application}_hutch_#{stage}` | Override if you run more than one Hutch unit per host (e.g. separate queue groups) — give each a distinct name. |

Nothing here needs to be checked into `config/puma.rb`-style app config — Hutch's own consumer/queue setup lives in your app as normal; this gem only manages the systemd unit and the deploy-time restart.

### First-Time Setup

Before your first deployment, install the systemd service on the target hosts:

```bash
$ bundle exec cap production hutch:install
```

This creates the unit file, runs `daemon-reload`, and enables the service (plus `loginctl enable-linger` for user-mode units, so it survives the deploy user logging out).

### Deployment

After the initial setup, normal deployments restart Hutch automatically:

```bash
$ bundle exec cap production deploy
```

To manually control the service:

```bash
$ bundle exec cap production hutch:start
$ bundle exec cap production hutch:stop
$ bundle exec cap production hutch:restart
$ bundle exec cap production hutch:status
```

To uninstall the systemd service:

```bash
$ bundle exec cap production hutch:uninstall
```

### Full Task List

```
$ cap -T hutch
cap hutch:disable         # Disable Hutch systemd service
cap hutch:enable          # Enable Hutch systemd service
cap hutch:install         # Install Hutch systemd service
cap hutch:reload          # Reload Hutch service via systemd (alias for restart)
cap hutch:restart         # Restart Hutch service via systemd
cap hutch:smart_restart   # Restarts Hutch service via systemd, honoring hutch_default_hooks
cap hutch:start           # Start Hutch service via systemd
cap hutch:status          # Get Hutch service status via systemd
cap hutch:stop            # Stop Hutch service via systemd
cap hutch:uninstall       # Uninstall Hutch systemd service
```

## Migrating from a hand-rolled PID-file setup

If you're replacing an existing `lib/capistrano/tasks/hutch.rake` that manages Hutch via a raw PID file (`bundle exec hutch --pidfile ... --daemon` + `kill -SIGINT`), this gem keeps the same `hutch_role` and `hutch_default_hooks` variable names on purpose — so an existing `config/deploy/<stage>.rb` that already sets those needs no changes beyond swapping the Capfile require/install and running `hutch:install` once per host. See `examples/` for a side-by-side.

## License

MIT

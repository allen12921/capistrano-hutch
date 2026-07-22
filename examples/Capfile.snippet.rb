# Add to Capfile, replacing:
#   Dir.glob('lib/capistrano/tasks/*.rake').each { |r| import r }
# picking up a hand-rolled hutch.rake — remove that file once this is wired up.

require 'capistrano/hutch'
install_plugin Capistrano::Hutch
install_plugin Capistrano::Hutch::Systemd

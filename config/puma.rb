max_threads_count = ENV.fetch('RAILS_MAX_THREADS', 5)
min_threads_count = ENV.fetch('RAILS_MIN_THREADS') { max_threads_count }
threads min_threads_count, max_threads_count

rails_env = ENV.fetch('RAILS_ENV', 'production')
environment rails_env

pidfile     ENV.fetch('PIDFILE') { "#{Dir.pwd}/tmp/pids/puma.pid" }
state_path  ENV.fetch('PUMA_STATE') { "#{Dir.pwd}/tmp/pids/puma.state" }

if rails_env == 'production'
  # Workers = number of CPU cores
  workers ENV.fetch('WEB_CONCURRENCY', 1)
  preload_app!

  bind "unix://#{Dir.pwd}/tmp/sockets/puma.sock"

  # Clean up connections after forking
  on_worker_boot do
    ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
  end

  before_fork do
    ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
  end
else
  port ENV.fetch('PORT', 3000)
end

plugin :tmp_restart

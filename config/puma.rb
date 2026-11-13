threads_count = ENV.fetch('RAILS_MAX_THREADS', 5)
threads threads_count, threads_count

environment ENV.fetch('RACK_ENV', 'development')

bind "tcp://0.0.0.0:#{ENV.fetch('PORT', 3000)}"

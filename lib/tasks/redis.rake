namespace :redis do
  desc 'Start redis'
  task :start do
    config_file = File.join(Dir.pwd, 'db/redis.conf')
    STDOUT.puts "Starting Redis with #{config_file}"
    exec "redis-server #{config_file}"
  end

  desc 'Stop redis'
  task :stop do
    STDOUT.puts "Shutting down Redis"
    exec 'redis-cli SHUTDOWN'
  end
end

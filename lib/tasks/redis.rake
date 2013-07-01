namespace :redis do
  desc 'Start redis'
  task :start do
    config_file = File.join(Dir.pwd, 'db/redis.conf')
    command = ("redis-server" + " #{config_file}") if File.exists?(config_file)
    STDOUT.puts "Starting Redis"
    exec command || "redis-server"
  end

  desc 'Stop redis'
  task :stop do
    STDOUT.puts "Shutting down Redis"
    exec 'redis-cli SHUTDOWN'
  end
end

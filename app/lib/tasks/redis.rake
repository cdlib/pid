namespace :redis do
  desc 'Start redis'
  
  base_exec = File.exists?("../local/bin/redis-server") ? "../local/bin/" : ""
  conf = File.exists?("../cdl/conf/redis.conf") ? "../local/bin/redis.conf" : File.exists?("#{Dir.pwd}/conf/redis.conf") ? "#{Dir.pwd}/conf/redis.conf" : "../shortcake-cdl/conf/redis.conf"
  
  task :start do
    config_file = File.join(Dir.pwd, "conf/redis.conf")
    command = ("#{base_exec}redis-server #{config_file}") if File.exists?(config_file)
    STDOUT.puts "Starting Redis using: #{command} (#{config_file})"
    exec command || "redis-server"
  end

  desc 'Stop redis'
  task :stop do
    STDOUT.puts "Shutting down Redis"
    exec "#{base_exec}redis-cli SHUTDOWN"
  end
end

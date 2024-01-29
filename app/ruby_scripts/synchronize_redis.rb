$parent_dir = File.expand_path('..', __dir__)

$LOAD_PATH.unshift(File.absolute_path(File.join($parent_dir, 'lib/shortcake')))
require 'shortcake'
require 'erb'
require 'yaml'
require 'active_record'

class PidApp
  
  $stdout.puts "Starting true-up of the Redis DB - #{Time.now}"
 
  begin
    
    app_config_file = File.exist?(File.join($parent_dir, 'config', 'app.yml')) ? File.join($parent_dir, 'config', 'app.yml') : File.join($parent_dir, 'config', 'app.yml.example')
    db_config_file = File.exist?(File.join($parent_dir, 'config', 'db.yml')) ? File.join($parent_dir, 'config', 'db.yml') : File.join($parent_dir, 'config', 'db.yml.example')
    security_config_file = File.exist?(File.join($parent_dir, 'config', 'security.yml')) ? File.join($parent_dir, 'config', 'security.yml') : File.join($parent_dir, 'config', 'security.yml.example')

    APP_CONFIG = YAML.safe_load(ERB.new(File.read(app_config_file)).result)
    DATABASE_CONFIG = YAML.safe_load(ERB.new(File.read(db_config_file)).result)
    SECURITY_CONFIG = YAML.safe_load(ERB.new(File.read(security_config_file)).result)

    URI_REGEX = /[fh]t{1,2}ps?:\/\/[a-zA-Z0-9\-_\.]+(:[0-9]+)?(\/[a-zA-Z0-9\/`~!@#\$%\^&\*\(\)\-_=\+{}\[\]\|\\;:'",<\.>\?])?/

    hostname = "http://#{APP_CONFIG['app_host']}:#{APP_CONFIG['app_port'].to_s}"

    args = {adapter: DATABASE_CONFIG['db_adapter'],
            host: DATABASE_CONFIG['db_host'],
            port: DATABASE_CONFIG['db_port'].to_i,
            database: DATABASE_CONFIG['db_name'],
            username: DATABASE_CONFIG['db_username'],
            password: DATABASE_CONFIG['db_password']}

    # Connect to the database
    $stdout.puts "Establishing connection to the #{DATABASE_CONFIG['db_name']} database on #{DATABASE_CONFIG['db_host']} - #{Time.now}"

    ActiveRecord::Base.establish_connection(args)

    # Load models
    $stdout.puts "Loading models - #{Time.now}"
    Dir.glob("#{$parent_dir}/models/*.rb").each { |r| require_relative r }
    
    # Connection to the REDIS database
    $stdout.puts "Establishing connection to the Redis database on #{APP_CONFIG['redis_host']}:#{APP_CONFIG['redis_port']}, ssl = #{APP_CONFIG['redis_use_ssl']} - #{Time.now}"
    @@shorty = Shortcake.new('pid', { host: APP_CONFIG['redis_host'], port: APP_CONFIG['redis_port'], ssl: APP_CONFIG['redis_use_ssl'] })

    # Delete all of the old REDIS records
    @@shorty.flushall!
  
    # Process the file of ids, urls
    $stdout.puts "Caching the PIDs in the Redis DB - #{Time.now}"
    Pid.find_each do |pid|
      url = if pid.nil? || pid.deactivated
              APP_CONFIG['dead_pid_url']
            else 
              pid.url.to_s
            end
      @@shorty.create_or_update(pid.id.to_s, url)
    end
    
  rescue Exception => e
    $stdout.puts "A fatal exception occurred! - #{e.message}"
  end
  
  $stdout.puts "Finished true-up of the Redis DB - #{Time.now}"
end

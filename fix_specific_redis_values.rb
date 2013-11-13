$LOAD_PATH.unshift(File.absolute_path(File.join(File.dirname(__FILE__), 'lib/shortcake')))
require 'rubygems'
require 'bundler/setup'

require 'yaml'
require "net/http"

require 'data_mapper'
require 'dm-sqlite-adapter'
require 'dm-mysql-adapter'
require 'dm-transactions'
require 'dm-timestamps'

require 'redis'
require 'shortcake'

class PidApp
  
  $stdout.puts "Starting specific PID update for Redis - #{Time.now}"
 
  begin 
    APP_CONFIG = YAML.load_file(File.exists?("/apps/purl/webapp/conf/app.yml") ? "/apps/purl/webapp/conf/app.yml" : 'conf/app.yml.example')
    DATABASE_CONFIG = YAML.load_file(File.exists?("/apps/purl/webapp/conf/db.yml") ? "/apps/purl/webapp/conf/db.yml" : 'conf/db.yml.example')
    SECURITY_CONFIG = YAML.load_file(File.exists?("/apps/purl/webapp/conf/security.yml") ? "/apps/purl/webapp/conf/security.yml" : 'conf/security.yml.example')
  
    URI_REGEX = /[fh]t{1,2}ps?:\/\/[a-zA-Z0-9\-_\.]+(:[0-9]+)?(\/[a-zA-Z0-9\/`~!@#\$%\^&\*\(\)\-_=\+{}\[\]\|\\;:'",<\.>\?])?/

    hostname = "http://#{APP_CONFIG['host']}:#{APP_CONFIG['port'].to_s}/"

    args = {:adapter => DATABASE_CONFIG['db_adapter'],
            :host => DATABASE_CONFIG['db_host'],
            :port => DATABASE_CONFIG['db_port'].to_i,
            :database => DATABASE_CONFIG['db_name'],
            :username => DATABASE_CONFIG['db_username'],
            :password => DATABASE_CONFIG['db_password']}

    DataMapper::Logger.new($stdout, :error)
    DataMapper.setup(:default, args)

    # load controllers and models
    Dir.glob("models/*.rb").each { |r| require_relative r }

    # finalize database models
    DataMapper::Model.raise_on_save_failure = true
    DataMapper.finalize.auto_upgrade!
  
    $stdout.puts "Opening /apps/purl/webapp/conf/redis_update.csv"
  
    pids = File.open("/apps/purl/webapp/conf/redis_update.csv")
  
    $stdout.puts "Processing file"
  
    # process the file of ids, urls
    CSV.foreach(pids) do |row| 
      id = row
    
      pid = Pid.first(:id => id)
      url = pid.nil? ? APP_CONFIG['dead_pid_url'] : (pid.deactivated ? APP_CONFIG['dead_pid_url'] : pid.url.to_s) 
    
      if !pid.nil?
        @@shorty.create_or_update(pid.id.to_s, url) unless pid.nil?
        $stdout.puts "updating redis record for pid #{id} to #{url}"
      else
        $stdout.puts "unable to find pid #{id}"
      end
    end
    
  rescue Exception => e
    puts "A fatal exception occurred! - #{e.message}"
  end
  
  $stdout.puts "Finished specific PID update for Redis - #{Time.now}"
end

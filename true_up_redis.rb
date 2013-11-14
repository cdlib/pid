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
  
  $stdout.puts "Starting true-up of the Redis DB - #{Time.now}"
 
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
  
    # establish a connection to the REDIS database
    @@shorty = Shortcake.new('pid', {:host => APP_CONFIG['redis_host'], :port => APP_CONFIG['redis_port']})
  
    # process the file of ids, urls
    Pid.all.each do |pid| 
      url = pid.nil? ? APP_CONFIG['dead_pid_url'] : (pid.deactivated ? APP_CONFIG['dead_pid_url'] : pid.url.to_s) 
      
      old_url = @@shorty.get(pid.id)
      
puts "old_url != url for #{pid.id} - #{old_url} != #{url}" if url != old_url
      
      @@shorty.create_or_update(pid.id.to_s, url) if url != old_url
    end
    
  rescue Exception => e
    puts "A fatal exception occurred! - #{e.message}"
  end
  
  $stdout.puts "Finished true-up of the Redis DB - #{Time.now}"
end

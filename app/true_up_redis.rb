$LOAD_PATH.unshift(File.absolute_path(File.join(File.dirname(__FILE__), 'lib/shortcake')))
require 'rubygems'
require 'bundler/setup'

require 'yaml'
require "net/http"

require 'redis'
require 'shortcake'
require 'active_record'

class PidApp
  
  $stdout.puts "Starting true-up of the Redis DB - #{Time.now}"
 
  begin
    APP_CONFIG = YAML.load_file(File.exist?("conf/app.yml") ? "conf/app.yml" : 'conf/app.yml.example')
    DATABASE_CONFIG = YAML.load_file(File.exist?("conf/db.yml") ? "conf/db.yml" : 'conf/db.yml.example')
    SECURITY_CONFIG = YAML.load_file(File.exist?("conf/security.yml") ? "conf/security.yml" : 'conf/security.yml.example')
  
    URI_REGEX = /[fh]t{1,2}ps?:\/\/[a-zA-Z0-9\-_\.]+(:[0-9]+)?(\/[a-zA-Z0-9\/`~!@#\$%\^&\*\(\)\-_=\+{}\[\]\|\\;:'",<\.>\?])?/

    hostname = "http://#{APP_CONFIG['app_host']}:#{APP_CONFIG['app_port'].to_s}/"

    args = {:adapter => DATABASE_CONFIG['db_adapter'],
            :host => DATABASE_CONFIG['db_host'],
            :port => DATABASE_CONFIG['db_port'].to_i,
            :database => DATABASE_CONFIG['db_name'],
            :username => DATABASE_CONFIG['db_username'],
            :password => DATABASE_CONFIG['db_password']}

    # set database
    $stdout.puts "Establishing connection to the #{DATABASE_CONFIG['db_name']} database on #{DATABASE_CONFIG['db_host']}"

    ActiveRecord::Base.establish_connection(DATABASE_CONFIG["activerecord_db"])

    # # load controllers and models
    # Dir.glob("controllers/*.rb").each { |r| require_relative r }
    Dir.glob("models/*.rb").each { |r| require_relative r }
    
    # establish a connection to the REDIS database
    @@shorty = Shortcake.new('pid', {:host => APP_CONFIG['redis_host'], :port => APP_CONFIG['redis_port']})
  
    # process the file of ids, urls
    Pid.all.each do |pid| 

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

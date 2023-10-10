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
  
  $stdout.puts "Starting duplicate URL scan - #{Time.now}"
 
  begin 
    APP_CONFIG = YAML.load_file(File.exists?("/apps/pid/webapp/conf/app.yml") ? "/apps/pid/webapp/conf/app.yml" : 'conf/app.yml.example')
    DATABASE_CONFIG = YAML.load_file(File.exists?("/apps/pid/webapp/conf/db.yml") ? "/apps/pid/webapp/conf/db.yml" : 'conf/db.yml.example')
    SECURITY_CONFIG = YAML.load_file(File.exists?("/apps/pid/webapp/conf/security.yml") ? "/apps/pid/webapp/conf/security.yml" : 'conf/security.yml.example')
  
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
  
    # Delete all of the old report results
    $stdout.puts "...Deleting old duplicate records."
    DuplicateUrlReport.all().destroy
  
    # Gather all of the PIDs that are active and loop through them verifying their URLs
    Pid.all(:deactivated => false).each do |pid|    
      dups = Pid.all(:url => pid.url, :deactivated => false, :id.not => pid.id)
    
      pids = []
      # Loopo through the duplicate URLs
      dups.each do |dup|      
        # If any duplicates were found add them to the pid as duplicates
        pids << "<a href='#{hostname}link/#{dup.id}'>#{dup.id}</a>"
      end

      begin
      
        unless pids.empty?
          # Add the originating PID to the list of duplicates
          pids << "<a href='#{hostname}link/#{pid.id}'>#{pid.id}</a>"
          
          # Save the record
          pid.mutable = true
          pid.duplicate_url_report = DuplicateUrlReport.new(:other_pids => pids.join(', '), :last_checked => Time.now)
          pid.save
          pid.mutable = false
        end
      
      rescue Exception => e
        puts "Failed to save duplicate information: #{e.message} - #{pid.id}"
      end
    end
  
  rescue Exception => e
    puts "A fatal exception occurred! - #{e.message}"
  end
  
  $stdout.puts "Finished adding #{DuplicateUrlReport.count} URLs from the duplicate URL scan - #{Time.now}"
end

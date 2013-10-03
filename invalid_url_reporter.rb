$LOAD_PATH.unshift(File.absolute_path(File.join(File.dirname(__FILE__), 'lib/shortcake')))
require 'shortcake'
require "net/http"
require "yaml"
require "data_mapper"
require 'dm-mysql-adapter'

class PidApp
  
  $stdout.puts "Starting invalid URL scan - #{Time.now}"
  
  begin
    APP_CONFIG = YAML.load_file(File.exists?("/apps/purl/webapp/conf/app.yml") ? "/apps/purl/webapp/conf/app.yml" : 'conf/app.yml.example')
    DATABASE_CONFIG = YAML.load_file(File.exists?("/apps/purl/webapp/conf/db.yml") ? "conf/db.yml" : '/apps/purl/webapp/conf/db.yml.example')
    SECURITY_CONFIG = YAML.load_file(File.exists?("/apps/purl/webapp/conf/security.yml") ? "/apps/purl/webapp/conf/security.yml" : 'conf/security.yml.example')
  
    URI_REGEX = /[fh]t{1,2}ps?:\/\/[a-zA-Z0-9\-_\.]+(:[0-9]+)?(\/[a-zA-Z0-9\/`~!@#\$%\^&\*\(\)\-_=\+{}\[\]\|\\;:'",<\.>\?])?/

    args = {:adapter => DATABASE_CONFIG['db_adapter'],
            :host => DATABASE_CONFIG['db_host'],
            :port => DATABASE_CONFIG['db_port'].to_i,
            :database => DATABASE_CONFIG['db_name'],
            :username => DATABASE_CONFIG['db_username'],
            :password => DATABASE_CONFIG['db_password']}

    DataMapper.setup(:default, args)

    # load controllers and models
    Dir.glob("models/*.rb").each { |r| 
      require_relative r
    }

    # finalize database models
    DataMapper::Model.raise_on_save_failure = true
    DataMapper.finalize.auto_upgrade!
  
    # Clear out all of the old records
    InvalidUrlReport.all.destroy
  
    # Gather all of the PIDs that are active and loop through them verifying their URLs
    Pid.all(:deactivated => false).each do |pid|  
      pid.verify_url
    end
  
  rescue Exception => e
    puts "A fatal exception occurred! - #{e.message}"
  end
  
  $stdout.puts "Finished adding #{DuplicateUrlReport.count} URLs from the invalid URL scan - #{Time.now}"
end
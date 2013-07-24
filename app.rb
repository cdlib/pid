# encoding: utf-8

# load shortcake (redis/url redirect wrapper)
$LOAD_PATH.unshift(File.absolute_path(File.join(File.dirname(__FILE__), 'lib/shortcake')))
require 'shortcake'

config = YAML.load_file('conf/db.yml')

class PidApp < Sinatra::Application
  enable :sessions # enable cookie-based sessions
  set :session_secret, 'super secret'
  set :sessions, :expire_after => 900
  
  set :root, File.dirname(__FILE__)
  
  # FIXME Extract database settings into a db.yml file
  configure :production do
    ENV['DATABASE_URL'] ||= "sqlite3://#{File.absolute_path(File.dirname(__FILE__))}/db/prod.db"
  end
  
  configure :development do
    ENV['DATABASE_URL'] ||= "sqlite3://#{File.absolute_path(File.dirname(__FILE__))}/db/dev.db"
  end
  
  configure :seeded do  
#    ENV['DATABASE_URL'] ||= "sqlite3://#{File.absolute_path(File.dirname(__FILE__))}/db/seeded.db"
    ENV['DATABASE_URL'] = "mysql://root:@localhost/seeded"
    
  end
  
  configure :test do
    ENV['DATABASE_URL'] ||= "sqlite::memory:"
  end
  
  helpers do
    include Rack::Utils
    alias_method :h, :escape_html
    
    def link_to(body, url=nil)
      url ||= body
      "<a href=\"#{url}\" target=\"_blank\">#{body || url}</a>"
    end
    
    def hostname()
      "#{request.scheme.to_s}://#{request.host.to_s}#{':' + request.port.to_s unless request.port.nil? }/"
    end
    
    def logged_in?
      return true if session[:user]
      nil
    end

    def current_user
      return session[:user]
    end
    
  end
end

# set database
puts "Establishing connection to the database"
DataMapper.setup(:default, ENV['DATABASE_URL'])

# load controllers and models
puts "Building controllers and models" 
Dir.glob("controllers/*.rb").each { |r| require_relative r }
Dir.glob("models/*.rb").each { |r| require_relative r }

# finalize database models
DataMapper::Model.raise_on_save_failure = true
DataMapper.finalize.auto_upgrade!

# Create Seed Data if we're in dev or test
if ENV['RACK_ENV'].to_sym == :seeded 
  require_relative 'db/seed.rb'
end

# OPTIMIZE - Should this go here?
#reload the Redis database from the data stored in the DB
if config['rebuild_redis_on_startup']
  puts "Rebuilding the Redis database for pid resolution"
  shorty = Shortcake.new('pid', {:host => 'localhost', :port => 6379})
  shorty.flushall!
  Pid.all.each do |pid| 
    begin
      shorty.create(pid.id.to_s, pid.url) if !pid.deactivated 
    rescue Exception => e
      puts "something happened while rebuilding the Redis DB for PID #{pid.id}: #{e.message}"
    end
  end
end
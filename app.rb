# encoding: utf-8

# load shortcake (redis/url redirect wrapper)
$LOAD_PATH.unshift(File.absolute_path(File.join(File.dirname(__FILE__), 'lib/shortcake')))
require 'shortcake'

class PidApp < Sinatra::Application
  $stdout.puts "loading configuration files"
  
  APP_CONFIG = YAML.load_file('conf/app.yml')
  DATABASE_CONFIG = YAML.load_file('conf/db.yml')
  SECURITY_CONFIG = YAML.load_file('conf/security.yml')
  MESSAGE_CONFIG = YAML.load_file('conf/message.yml')
  HTML_CONFIG = YAML.load_file('conf/html.yml')

  URI_REGEX = /[fh]t{1,2}ps?:\/\/[a-zA-Z0-9\-_\.]+(:[0-9]+)?(\/[a-zA-Z0-9\/`~!@#\$%\^&\*\(\)\-_=\+{}\[\]\|\\;:'",<\.>\?])?/

  enable :sessions # enable cookie-based sessions
  set :session_secret, ENV[SECURITY_CONFIG['session_secret']]
  set :sessions, :expire_after => SECURITY_CONFIG['session_expires']
  
  set :root, File.dirname(__FILE__)
  
  args = nil
  
  configure :production do
    args = {:adapter => DATABASE_CONFIG['db_adapter'],
            :host => DATABASE_CONFIG['db_host'],
            :port => DATABASE_CONFIG['db_port'].to_i,
            :database => DATABASE_CONFIG['db_name'],
            :username => ENV[DATABASE_CONFIG['db_username']],
            :password => ENV[DATABASE_CONFIG['db_password']]}
  end
  
  configure :development do
    args = {:adapter => DATABASE_CONFIG['db_adapter'],
            :host => DATABASE_CONFIG['db_host'],
            :port => DATABASE_CONFIG['db_port'].to_i,
            :database => DATABASE_CONFIG['db_name'],
            :username => ENV[DATABASE_CONFIG['db_username']],
            :password => ENV[DATABASE_CONFIG['db_password']]}
  end
  
  configure :seeded do  
    args = {:adapter => DATABASE_CONFIG['db_adapter'],
            :host => DATABASE_CONFIG['db_host'],
            :port => DATABASE_CONFIG['db_port'].to_i,
            :database => DATABASE_CONFIG['db_name'],
            :username => ENV[DATABASE_CONFIG['db_username']],
            :password => ENV[DATABASE_CONFIG['db_password']]}
  end
  
  configure :test do
    args = ENV['DATABASE_URL'] ||= "sqlite::memory:"
  end
  
  # set database
  $stdout.puts "Establishing connection to the #{DATABASE_CONFIG['db_name']} database on #{DATABASE_CONFIG['db_host']}"

  DataMapper.setup(:default, args)

  # load controllers and models
  $stdout.puts "Building controllers and models" 
  Dir.glob("controllers/*.rb").each { |r| require_relative r }
  Dir.glob("models/*.rb").each { |r| require_relative r }

  # finalize database models
  #DataMapper::Logger.new(STDOUT, :debug)
  DataMapper::Model.raise_on_save_failure = true
  DataMapper.finalize.auto_upgrade!

  # Create Seed Data if we're in dev or test
  if ENV['RACK_ENV'].to_sym == :seeded 
    require_relative 'db/seed.rb'
  end

  # OPTIMIZE - Should this go here?
  #reload the Redis database from the data stored in the DB
  if DATABASE_CONFIG['rebuild_redis_on_startup']
    $stdout.puts "Rebuilding the Redis database for pid resolution"
    shorty = Shortcake.new('pid', {:host => APP_CONFIG['redis_host'], :port => APP_CONFIG['redis_port']})
    shorty.flushall!
    Pid.all.each do |pid| 
      begin
        shorty.create(pid.id.to_s, (pid.deactivated ? 
            "http://#{APP_CONFIG['host']}#{':' + APP_CONFIG['port'].to_s unless APP_CONFIG['port'].nil? }/link/dead"  : pid.url))
      rescue Exception => e
        $stdout.puts "something happened while rebuilding the Redis DB for PID #{pid.id}: #{e.message}"
      end
    end
  end
  
  helpers do
    include Rack::Utils
    alias_method :h, :escape_html
    
    def link_to(body, url=nil)
      url ||= body
      "<a href=\"#{url}\" target=\"_blank\">#{body || url}</a>"
    end
    
    def hostname()
      "#{request.scheme.to_s}://#{APP_CONFIG['host']}#{':' + APP_CONFIG['port'].to_s unless APP_CONFIG['port'].nil? }/"
    end
    
    def logged_in?
      return true if session[:user]
      nil
    end

    def current_user
      return User.get(session[:user])
    end
    
  end
end


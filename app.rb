# encoding: utf-8

# load shortcake (redis/url redirect wrapper)
$LOAD_PATH.unshift(File.absolute_path(File.join(File.dirname(__FILE__), 'lib/shortcake')))
require 'shortcake'
require "net/http"

class PidApp < Sinatra::Application
  $stdout.puts "loading configuration files"
  
  APP_CONFIG = YAML.load_file('conf/app.yml')
  DATABASE_CONFIG = YAML.load_file('conf/db.yml')
  SECURITY_CONFIG = YAML.load_file('conf/security.yml')
  MESSAGE_CONFIG = YAML.load_file('conf/message.yml')
  HTML_CONFIG = YAML.load_file('conf/html.yml')

  URI_REGEX = /[fh]t{1,2}ps?:\/\/[a-zA-Z0-9\-_\.]+(:[0-9]+)?(\/[a-zA-Z0-9\/`~!@#\$%\^&\*\(\)\-_=\+{}\[\]\|\\;:'",<\.>\?])?/

  DEAD_PID_URL = (APP_CONFIG['dead_pid_url'].nil?) ? "#{hostname}link/dead" : APP_CONFIG['dead_pid_url']

  enable :sessions # enable cookie-based sessions
  set :session_secret, SECURITY_CONFIG['session_secret']
  set :sessions, :expire_after => SECURITY_CONFIG['session_expires']
  
  set :root, File.dirname(__FILE__)
  
  args = args = {:adapter => DATABASE_CONFIG['db_adapter'],
            :host => DATABASE_CONFIG['db_host'],
            :port => DATABASE_CONFIG['db_port'].to_i,
            :database => DATABASE_CONFIG['db_name'],
            :username => DATABASE_CONFIG['db_username'],
            :password => DATABASE_CONFIG['db_password']}
  
  # If we're in test mode switch to SQLite and a temp Redis secret
  configure :test do
    args = "sqlite::memory:"
    set :session_secret, 'test_redis_secret'
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

  # Create the default admin account if the security file indicates that we should do so
  if SECURITY_CONFIG['create_default_admin']
    $stdout.puts 'Creating default administrator'
    
    grp = Group.get(SECURITY_CONFIG['default_group_id']) 
    grp = Group.new({:id => SECURITY_CONFIG['default_group_id'], :name => SECURITY_CONFIG['default_group_name']}).save if grp.nil?

    adm = User.new({:login => SECURITY_CONFIG['default_admin_login'],
                    :name => SECURITY_CONFIG['default_admin_name'],
                    :password => SECURITY_CONFIG['default_admin_password'],
                    :email => SECURITY_CONFIG['default_admin_email'],
                    :group => grp,
                    :super => true})
    grp.users << adm
    grp.save
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

# ---------------------------------------------------------------------------------------------------
# Wrappers for accessing the security framework
# ---------------------------------------------------------------------------------------------------
    def logged_in?
      return true if session[:user]
      nil
    end

    def current_user
      return User.get(session[:user])
    end
    
# ---------------------------------------------------------------------------------------------------
# Ping the PID's target URL to see if its valid
#     TODO: Determine whether or not we can do this. We may need to store a list of domains in the
#           DB for companies/institutions that do not allow this 
#
#     SCP - not allowed by contract to check live URLs automatically
#           for all journals. Will happen while loading seed data, editing in masse.
# ---------------------------------------------------------------------------------------------------        
    def verify_url(url)
=begin      
      #Test to make sure this a valid URL
      uri = URI.parse(url)
      req = Net::HTTP.new(uri.host, uri.port)
      if uri.path.empty?
        res = req.request_get(url)
      else
        res = req.request_head(uri.path) 
      end
          
      res.code.to_i  
=end
      200
    end
    
# ---------------------------------------------------------------------------------------------------
# Check Redis to see if the specified PID has the same URL as another PID
# ---------------------------------------------------------------------------------------------------        
    def hasDuplicate(url, pid)
      shorty = Shortcake.new('pid', {:host => 'localhost', :port => 6379})
      ret = []
      
      pids = shorty.get(url)
      
      if !pids.nil?
        if pids.size > 1
          ret = pids
        end
      end
      
      ret
    end
    
# ---------------------------------------------------------------------------------------------------
# Retrieve default parameters from the DB for use on PID search and report views
# ---------------------------------------------------------------------------------------------------    
    def get_search_defaults(params) 
      # Create stub defaults if the params are empty
      defaults = {:pid_min => 0, :pid_max => 0, :modified_low => '', :modified_high => '', :created_low => '', :created_high => '',
                  :accessed_low => '', :accessed_high => '', :users => [], :group => nil} 
    
      # If the group (or system in the case of a super user) has PIDs find the first and last otherwise default to generic values
      args = {}
      args = {:group => current_user.group} unless current_user.super
      
      # Load the low and high values for the defaults
      if !Pid.first().nil?
        defaults[:pid_min] = Pid.first(args, :order => [:id.asc]).id
        defaults[:pid_max] = Pid.first(args, :order => [:id.desc]).id
        defaults[:modified_low] = Pid.first(args, :order => [:modified_at.asc]).modified_at.strftime("%Y-%m-%d")
        defaults[:modified_high] = Pid.first(args, :order => [:modified_at.desc]).modified_at.strftime("%Y-%m-%d")
        defaults[:created_low] = Pid.first(args, :order => [:created_at.asc]).created_at.strftime("%Y-%m-%d")
        defaults[:created_high] = Pid.first(args, :order => [:created_at.desc]).created_at.strftime("%Y-%m-%d")
      end
      
      if !Statistic.first().nil?
        defaults[:accessed_low] = Statistic.first(args, :order => [:accessed.asc]).accessed.strftime("%Y-%m-%d")
        defaults[:accessed_high] = Statistic.first(args, :order => [:accessed.desc]).accessed.strftime("%Y-%m-%d")
      end
      
      # If either of the PID range values that were passed in then use the default
      params[:pid_low] = defaults[:pid_min] if (params[:pid_low].nil? ? true : params[:pid_low].empty?)
      params[:pid_high] = defaults[:pid_max] if (params[:pid_high].nil? ? true : params[:pid_high].empty?)
    
      # If the date ranges that were passed in were empty then use the default
      params[:created_low] = defaults[:created_low] if (params[:created_low].nil? ? true : params[:created_low].empty?)
      params[:created_high] = defaults[:created_high] if (params[:created_high].nil? ? true : params[:created_high].empty?)
      params[:modified_low] = defaults[:modified_low] if (params[:modified_low].nil? ? true : params[:modified_low].empty?)
      params[:modified_high] = defaults[:modified_high] if (params[:modified_high].nil? ? true : params[:modified_high].empty?)
      params[:accessed_low] = defaults[:accessed_low] if (params[:accessed_low].nil? ? true : params[:accessed_low].empty?)
      params[:accessed_high] = defaults[:accessed_high] if (params[:accessed_high].nil? ? true : params[:accessed_high].empty?)
      
      # If the PID high range is less than the low range, swap them 
      params[:pid_low], params[:pid_high] = params[:pid_high], params[:pid_low] if params[:pid_high].to_i < params[:pid_low].to_i
      
      # Load the list of users available to the user
      params[:users] = (current_user.super) ? User.all(:order => [:login.asc]) : User.all(:group => current_user.group, :order => [:login.asc])
      
      params
    end
  end
end


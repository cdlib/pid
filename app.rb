# encoding: utf-8

# load shortcake (redis/url redirect wrapper)
$LOAD_PATH.unshift(File.absolute_path(File.join(File.dirname(__FILE__), 'lib/shortcake')))
require 'shortcake'
require "net/http"
require 'pony'

class PidApp < Sinatra::Application
  $stdout.puts "loading configuration files"
  
  base = 'conf/'
  configure :production, :stage do
    base = '../cdl/conf/'
  end
  
  APP_CONFIG = YAML.load_file(File.exists?("#{base}app.yml") ? "#{base}app.yml" : 'conf/app.yml.example')
  DATABASE_CONFIG = YAML.load_file(File.exists?("#{base}db.yml") ? "#{base}db.yml" : 'conf/db.yml.example')
  SECURITY_CONFIG = YAML.load_file(File.exists?("#{base}security.yml") ? "#{base}security.yml" : 'conf/security.yml.example')
  MESSAGE_CONFIG = YAML.load_file(File.exists?("#{base}message.yml") ? "#{base}message.yml" : 'conf/message.yml.example')
  HTML_CONFIG = YAML.load_file(File.exists?("#{base}html.yml") ? "#{base}html.yml" : 'conf/html.yml.example')

  URI_REGEX = /[fh]t{1,2}ps?:\/\/[a-zA-Z0-9\-_\.]+(:[0-9]+)?(\/[a-zA-Z0-9\/`~!@#\$%\^&\*\(\)\-_=\+{}\[\]\|\\;:'",<\.>\?])?/

  args = {:adapter => DATABASE_CONFIG['db_adapter'],
          :host => DATABASE_CONFIG['db_host'],
          :port => DATABASE_CONFIG['db_port'].to_i,
          :database => DATABASE_CONFIG['db_name'],
          :username => DATABASE_CONFIG['db_username'],
          :password => DATABASE_CONFIG['db_password']}
  
  set :session_secret, SECURITY_CONFIG['session_secret']

  # If we're in test mode switch to SQLite and a temp Redis secret
  configure :test do
    args = "sqlite::memory:"
    set :session_secret, 'test_redis_secret'
  end    

  DEAD_PID_URL = (APP_CONFIG['dead_pid_url'].nil?) ? "#{hostname}link/dead" : APP_CONFIG['dead_pid_url']

  enable :sessions # enable cookie-based sessions
  
  set :sessions, :expire_after => SECURITY_CONFIG['session_expires']
  
  set :root, File.dirname(__FILE__)
  
  configure :production, :stage do
    enable :logging
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
      session[:msg] = MESSAGE_CONFIG['session_expired']
      nil
    end

    def current_user
      return User.get(session[:user])
    end
    
    def is_group_maintainer?
      return !Maintainer.first(:user => current_user).nil?
    end
    
# ---------------------------------------------------------------------------------------------------
# Process to verify that the url is a valid target
# ---------------------------------------------------------------------------------------------------
    def verify_url(url)
      skip = false
      
      SkipCheck.all().each{ |it| skip = true if url.downcase.include?(it.domain.downcase) }
      
      if !skip
            
        #Test to make sure this a valid URL
        uri = URI.parse(url)
        req = Net::HTTP.new(uri.host, uri.port)
        if uri.path.empty?
          res = req.request_get(url)
        else
          res = req.request_head(uri.path) 
        end
          
        res.code.to_i  
      else
        200
      end
      
    end
    
# ---------------------------------------------------------------------------------------------------
# Check Redis to see if the specified PID has the same URL as another PID
# ---------------------------------------------------------------------------------------------------        
    def hasDuplicate(url, pid)
      shorty = Shortcake.new('pid', {:host => 'localhost', :port => 6379})
      ret = []
      
      # Convert the string returned by Redis to an array
      pids = shorty.get(url)
      
      if !pids.nil?
        pids = pids.gsub(/[\[\]"]/, '').split(',')
      
        # Add the PID's id to the return array if its not the pid specified
        pids.each { |it| ret << it unless it == pid } unless pids.empty?
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

      if !Pid.first(args).nil?
        args[:order] = [:id.asc]
        params[:pid_min] = Pid.first(args).id
        
        args[:order] = [:id.desc]
        params[:pid_max] = Pid.first(args).id
        
        args[:order] = [:modified_at.asc]
        params[:modified_min] = Pid.first(args).modified_at.strftime("%m/%d/%Y")
        
        args[:order] = [:modified_at.desc]
        params[:modified_max] = Pid.first(args).modified_at.strftime("%m/%d/%Y")
        
        args[:order] = [:created_at.asc]
        params[:created_min] = Pid.first(args).created_at.strftime("%m/%d/%Y")
        
        args[:order] = [:created_at.desc]
        params[:created_max] = Pid.first(args).created_at.strftime("%m/%d/%Y")
      end

      # If the PID high range is less than the low range, swap them 
      params[:pid_low], params[:pid_high] = params[:pid_high], params[:pid_low] if params[:pid_high].to_i < params[:pid_low].to_i
      
      # Load the list of users available to the user
      params[:users] = (current_user.super) ? User.all(:order => [:login.asc]) : User.all(:group => current_user.group, :order => [:login.asc])
      
      params
    end
  end
  
  def send_email(to, subject, body)

    args = {:from => APP_CONFIG['email_sender_address'],
              :to => to,
              :subject => subject,
              :body => body}

    # If the app config file specifies that we should use smtp, add the smtp args
    if APP_CONFIG['email_method'].downcase == 'smtp'
      args[:via] = :smtp
      args[:smtp] = {:host => APP_CONFIG['smtp_host'],
                     :port => APP_CONFIG['smtp_port'],
                     :user => APP_CONFIG['smtp_user'],
                     :password => APP_CONFIG['smtp_pwd'],
                     :auth => :plain,
                     :domain => APP_CONFIG['smtp_domain']}
    end

    Pony.mail args
  end
  
end


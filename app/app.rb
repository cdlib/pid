# encoding: utf-8

# load shortcake (redis/url redirect wrapper)
$LOAD_PATH.unshift(File.absolute_path(File.join(File.dirname(__FILE__), 'lib/shortcake')))
require 'shortcake'
require 'net/http'
require 'mail'
require 'erb'
require 'yaml'
require 'active_record'
require 'sinatra/base'

# ActiveRecord::Base.logger = Logger.new(STDOUT)
# ActiveRecord::Base.logger.level = Logger::DEBUG

class PidApp < Sinatra::Base
  
  $stdout.puts "Loading configuration files"
  
  app_config_file = File.exist?(File.join(__dir__, 'config', 'app.yml')) ? File.join(__dir__, 'config', 'app.yml') : File.join(__dir__, 'config', 'app.yml.example')
  db_config_file = File.exist?(File.join(__dir__, 'config', 'db.yml')) ? File.join(__dir__, 'config', 'db.yml') : File.join(__dir__, 'config', 'db.yml.example')
  security_config_file = File.exist?(File.join(__dir__, 'config', 'security.yml')) ? File.join(__dir__, 'config', 'security.yml') : File.join(__dir__, 'config', 'security.yml.example')
  message_config_file = File.exist?(File.join(__dir__, 'config', 'message.yml')) ? File.join(__dir__, 'config', 'message.yml') : File.join(__dir__, 'config', 'message.yml.example')
  html_config_file = File.exist?(File.join(__dir__, 'config', 'html.yml')) ? File.join(__dir__, 'config', 'html.yml') : File.join(__dir__, 'config', 'html.yml.example')

  APP_CONFIG = YAML.safe_load(ERB.new(File.read(app_config_file)).result)
  DATABASE_CONFIG = YAML.safe_load(ERB.new(File.read(db_config_file)).result)
  SECURITY_CONFIG = YAML.safe_load(ERB.new(File.read(security_config_file)).result)
  MESSAGE_CONFIG = YAML.safe_load(ERB.new(File.read(message_config_file)).result)
  HTML_CONFIG = YAML.safe_load(ERB.new(File.read(html_config_file)).result)

  URI_REGEX = /[fh]t{1,2}ps?:\/\/[0-9\p{L}\-_\.]+(:[0-9]+)?(\/[\p{L}\/`~!@#\$%\^&\*\(\)\-_=\+{}\[\]\|\\;:'",<\.>\?])?/

  args = {
    adapter: DATABASE_CONFIG['db_adapter'],
    encoding: DATABASE_CONFIG['db_encoding'],
    host: DATABASE_CONFIG['db_host'],
    port: DATABASE_CONFIG['db_port'].to_i,
    database: DATABASE_CONFIG['db_name'],
    username: DATABASE_CONFIG['db_username'],
    password: DATABASE_CONFIG['db_password']
  }
  
  TEST_MODE = false

  # If we're in test mode switch to SQLite and a temp Redis secret
  configure :test do
    args = {
      adapter: 'sqlite3',
      database: 'db/test.sqlite3'
    }

    APP_CONFIG['redis_host'] = 'localhost'
    APP_CONFIG['redis_port'] = '1000'
    APP_CONFIG['redis_use_ssl'] = 'false'
    DATABASE_CONFIG['rebuild_redis_on_startup'] = 'false'

    # ENV variables are not loaded for some reason and these two are needed to define the dead_pid_url
    # which is crucial for the PID Controller tests.
    APP_CONFIG['app_host'] = 'localhost' 
    APP_CONFIG['app_port'] = '3000'

    TEST_MODE = true
  end    

  set :session_secret, SECURITY_CONFIG['session_secret']

  enable :sessions # enable cookie-based sessions
  
  set :sessions, :expire_after => SECURITY_CONFIG['session_expires']
  
  set :root, File.dirname(__FILE__)
  
  configure :development, :production, :stage do
    enable :logging
  end
  
  ses_smtp_host = APP_CONFIG['smtp_host']
  ses_smtp_port = APP_CONFIG['smtp_port']
  ses_smtp_username = APP_CONFIG['smtp_username']
  ses_smtp_password = APP_CONFIG['smtp_password']

  Mail.defaults do
    delivery_method :smtp, {
      address: ses_smtp_host,
      port: ses_smtp_port,
      user_name: ses_smtp_username,
      password: ses_smtp_password,
      authentication: :login
    }
  end

  # set database
  unless TEST_MODE
    $stdout.puts "Establishing connection to the #{DATABASE_CONFIG['db_name']} database on #{DATABASE_CONFIG['db_host']}"
  end

  ActiveRecord::Base.establish_connection(args)

  # load controllers and models
  $stdout.puts "Building controllers and models" 
  Dir.glob("controllers/*.rb").each { |r| require_relative r }
  Dir.glob("models/*.rb").each { |r| require_relative r }

  # Create Seed Data if we're in dev or test
  if ENV['RACK_ENV'].to_sym == :seeded 
    require_relative 'db/seed.rb'
  end

  # Create the default admin account if the security file indicates that we should do so
  if SECURITY_CONFIG['create_default_admin']
    $stdout.puts 'Creating default administrator'
    
    grp = Group.get(SECURITY_CONFIG['default_group_id']) 
    grp = Group.new({id: SECURITY_CONFIG['default_group_id'], name: SECURITY_CONFIG['default_group_name']}).save if grp.nil?

    adm = User.new({login: SECURITY_CONFIG['default_admin_login'],
                    name: SECURITY_CONFIG['default_admin_name'],
                    password: SECURITY_CONFIG['default_admin_password'],
                    email: SECURITY_CONFIG['default_admin_email'],
                    group: grp,
                    super: true})
    grp.users << adm
    grp.save
  end
  
  helpers do
    include Rack::Utils
    alias_method :h, :escape_html
    
    def link_to(body, url=nil)
      url ||= body
      "<a href=\"#{url}\" target=\"_blank\">#{body || url}</a>"
    end
    
    def hostname
      "#{request.scheme.to_s}://#{APP_CONFIG['app_host']}"
    end
  

# ---------------------------------------------------------------------------------------------------
# Wrappers for accessing the security framework
# ---------------------------------------------------------------------------------------------------
    def logged_in?
      if session[:user] 
        true
      else
        session[:msg] = MESSAGE_CONFIG['session_expired']
        false
      end
    end

    def current_user
      User.find_by(id: session[:user])
    end

    def is_group_maintainer?
      !Maintainer.find_by(user: current_user).nil?
    end

# ---------------------------------------------------------------------------------------------------
# Find other PIDs with the same URL as the given PID
# ---------------------------------------------------------------------------------------------------        
    def findDuplicate(url, pid_id)
      duplicate_ids = Pid.where(url: url).pluck(:id)
      duplicate_ids.delete(pid_id) if duplicate_ids.any?
      duplicate_ids
    end
    
# ---------------------------------------------------------------------------------------------------
# Retrieve default parameters from the DB for use on PID search and report views
# ---------------------------------------------------------------------------------------------------    
    def get_search_defaults(params)
      defaults = {:pid_min => 0, :pid_max => 0, :modified_low => '', :modified_high => '', :created_low => '', :created_high => '',
                    :accessed_low => '', :accessed_high => '', :users => [], :group => nil}

      return defaults unless logged_in?
    
      args = {}
      args[:group] = current_user.group unless current_user.super || current_user.read_only
    
      if Pid.where(args).exists?
        params[:pid_min] = Pid.where(args).order(id: :asc).first.id
        params[:pid_max] = Pid.where(args).order(id: :desc).first.id
        params[:modified_min] = Pid.where(args).order(modified_at: :asc).first.modified_at.strftime("%m/%d/%Y")
        params[:modified_max] = Pid.where(args).order(modified_at: :desc).first.modified_at.strftime("%m/%d/%Y")
        params[:created_min] = Pid.where(args).order(created_at: :asc).first.created_at.strftime("%m/%d/%Y")
        params[:created_max] = Pid.where(args).order(created_at: :desc).first.created_at.strftime("%m/%d/%Y")
      end
    
      params[:pid_low], params[:pid_high] = params[:pid_high], params[:pid_low] if params[:pid_high].to_i < params[:pid_low].to_i
    
      params[:groups] = Group.all
      params[:users] = User.all
    
      Maintainer.where(user: current_user).each do |maint|
        if maint.group != current_user.group
          User.where(group: maint.group).each do |usr|
            params[:users] << usr unless params[:users].include?(usr)
          end
        end
      end
      
      params[:users] = params[:users].to_a if params[:users].is_a?(ActiveRecord::Relation)
      params[:groups] = params[:groups].to_a if params[:groups].is_a?(ActiveRecord::Relation)

      params[:users].sort! { |x, y| x.login <=> y.login }
      params[:groups].sort! { |x, y| x.id <=> y.id }
    
      params
    end
  end

  def valid_email?(email)
    # Define a regular expression for a basic email format
    email_regex = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  
    # Check if the email matches the regular expression
    !!(email =~ email_regex)
  end

  def send_email(to, subject, body)
    return if TEST_MODE

    sender_address = APP_CONFIG['email_sender_address']
    mail = Mail.new do
      from sender_address
      to to
      subject subject
      body body
    end
    mail.deliver!
  end

end


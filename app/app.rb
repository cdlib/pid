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
require "will_paginate/view_helpers/sinatra"
require "will_paginate/active_record"

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

  configure :development, :production do
    enable :logging
    
    PERMITTED_HOSTNAMES = [] # allow all hosts
    set :host_authorization, { permitted_hosts: PERMITTED_HOSTNAMES }
  end

  set :session_secret, SECURITY_CONFIG['session_secret']

  enable :sessions # enable cookie-based sessions
  
  set :sessions, :expire_after => SECURITY_CONFIG['session_expires']
  
  set :root, File.dirname(__FILE__)
  
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
      "#{request.scheme}://#{request.host}:#{request.port}"
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


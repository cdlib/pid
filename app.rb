# encoding: utf-8

# load shortcake (redis/url redirect wrapper)
$LOAD_PATH.unshift(File.absolute_path(File.join(File.dirname(__FILE__), 'lib/shortcake')))
require 'shortcake'

class PidApp < Sinatra::Application
  enable :sessions # enable cookie-based sessions
  set :session_secret, 'super secret'
  
  set :root, File.dirname(__FILE__)
  
  configure :production do
    ENV['DATABASE_URL'] ||= "sqlite3://#{File.absolute_path(File.dirname(__FILE__))}/db/prod.db"
  end
  
  configure :development do
    ENV['DATABASE_URL'] ||= "sqlite3://#{File.absolute_path(File.dirname(__FILE__))}/db/dev.db"
  end
  
  configure :test do
    ENV['DATABASE_URL'] ||= "sqlite3://#{File.absolute_path(File.dirname(__FILE__))}/test/test.db"
  end
  
  helpers do
    include Rack::Utils
    alias_method :h, :escape_html
  end
end

# set database
DataMapper.setup(:default, ENV['DATABASE_URL'])

# load controllers and models
Dir.glob("controllers/*.rb").each { |r| require_relative r }
Dir.glob("models/*.rb").each { |r| require_relative r }

# finalize database models
DataMapper::Model.raise_on_save_failure = true
DataMapper.finalize.auto_upgrade!

# Create Seed Data
require_relative 'db/seed.rb'
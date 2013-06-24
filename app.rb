# encoding: utf-8

# load shortcake (redis/url redirect wrapper)
$LOAD_PATH.unshift(File.absolute_path(File.join(File.dirname(__FILE__), 'lib/shortcake')))
require 'shortcake'

# miniframework, object relational model
require 'sinatra'
require 'data_mapper'
require 'dm-transactions'

# set database
DataMapper.setup(:default, ENV['DATABASE_URL'])

# load controllers and models
Dir.glob("controllers/*.rb").each { |r| require_relative r }
Dir.glob("models/*.rb").each { |r| require_relative r }

# finalize database models
DataMapper::Model.raise_on_save_failure = true
DataMapper.finalize.auto_upgrade!

class PidApp < Sinatra::Application
  enable :sessions # enable cookie-based sessions
  
  configure :production do
    # TBD
  end
  
  configure :development do
    # TBD
  end
  
  configure :test do
    # TBD
  end
  
  helpers do
    include Rack::Utils
    alias_method :h, :escape_html
  end
end


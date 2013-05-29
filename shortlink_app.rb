require 'sinatra'
require './lib/shortcake/shortcake'

redis = Redis.new
shorty = Shortcake.new('short', {:host => "localhost", :port => 6379})

helpers do
  include Rack::Utils
  alias_method :h, :escape_html

  def random_string(length)
    rand(36**length).to_s(36)
  end
end

get '/' do
  erb :index
end

post '/' do
  if params[:url] and not params[:url].empty?
    @shortcode = random_string 5
    shorty.create(@shortcode, params[:url])
  end
  erb :index
end

get '/:shortcode' do
  @url = shorty.get(params[:shortcode])
  redirect @url || '/'
end

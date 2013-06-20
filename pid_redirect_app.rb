require 'sinatra'
require './lib/shortcake/shortcake'

redis = Redis.new
shorty = Shortcake.new('short', {:host => "localhost", :port => 6379})
shorty.create_or_update('1234', 'http://google.com')
CODE_AND_PARTIAL = Regexp.compile(/^(\/[0-9]{1,12})(.*)/)

get %r{/([0-9]{1,12}/.+)} do
  shortcode, code, partial = request.fullpath.match(CODE_AND_PARTIAL).to_a 
  url = shorty.get(code[1,code.length])
  url.nil? ? 404 : redirect(url + partial.to_s)
end

get '/:shortcode' do
  url = shorty.get(params[:shortcode])
  url.nil? ? 404 : redirect(url)
end
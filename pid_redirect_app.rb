$LOAD_PATH.unshift(File.absolute_path(File.join(File.dirname(__FILE__), 'models')))
require 'sinatra'
require 'shortcake'

redis = Redis.new
shorty = Shortcake.new('short', {:host => "localhost", :port => 6379})
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
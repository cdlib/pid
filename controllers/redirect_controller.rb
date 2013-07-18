class PidApp < Sinatra::Application
  
  #FIXME - move Redis host and port to YAML
  
  redis = Redis.new
  shorty = Shortcake.new('pid', {:host => "localhost", :port => 6379})
  CODE_AND_PARTIAL = Regexp.compile(/^\/PID\/([0-9]{1,12})(.*)/)

  get %r{/PID/([0-9]{1,12}/.+)} do
    shortcode, code, partial = request.fullpath.match(CODE_AND_PARTIAL).to_a 
    url = shorty.get(code)
    url.nil? ? 404 : redirect(url + partial.to_s)
  end

  get '/PID/:shortcode' do
    url = shorty.get(params[:shortcode])
    url.nil? ? 404 : redirect(url)
  end
  
end
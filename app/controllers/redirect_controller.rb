require 'uri'

class PidApp < Sinatra::Base
  redis = Redis.new
  shorty = Shortcake.new('pid', { host: PidApp::APP_CONFIG['redis_host'], port: PidApp::APP_CONFIG['redis_port'], ssl: PidApp::APP_CONFIG['redis_use_ssl'] })
  CODE_AND_PARTIAL = Regexp.compile(/^\/PID\/([0-9]{1,12})(.*)/)

  get %r{/PID/([0-9]{1,12}/.+)} do
    shortcode, code, partial = request.fullpath.match(CODE_AND_PARTIAL).to_a 
    
    url = shorty.get(code)
    
    if !url.nil?
      # if the last character of the url is a ['?', '&', '='] then remove the 1st character of the partial, which is a '/'
      partial = partial[1..partial.length] if ["?", "&", "="].include?(url.last)
    end
    
    url.nil? ? 404 : redirect(url + partial.to_s)
  end

  get '/PID/:shortcode' do
    url = shorty.get(params[:shortcode])
    url.nil? ? 404 : redirect(url)
  end

end

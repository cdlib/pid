
class PidApp < Sinatra::Application
  
  #FIXME - move Redis host and port to YAML
  
  redis = Redis.new
  shorty = Shortcake.new('pid', {:host => "localhost", :port => 6379})
  CODE_AND_PARTIAL = Regexp.compile(/^\/PID\/([0-9]{1,12})(.*)/)

  get %r{/PID/([0-9]{1,12}/.+)} do
    shortcode, code, partial = request.fullpath.match(CODE_AND_PARTIAL).to_a 
    url = shorty.get(code)
    
    begin
      record_statistic(url, request) unless url.nil?
    end
    
    url.nil? ? 404 : redirect(url + partial.to_s)
  end


  get '/PID/:shortcode' do
    url = shorty.get(params[:shortcode])
    
    begin
      record_statistic(url, request) unless url.nil?
    end
    
    url.nil? ? 404 : redirect(url)
  end
  
private
  def record_statistic(url, request)
    begin
      pid = Pid.get(params[:shortcode])
    
      stat = Statistic.new(:pid => pid, :accessed => Time.now, :accessor => request.ip.to_s, :referrer => request.referrer, 
                          :target => pid.url, :agent => request.env['HTTP_USER_AGENT'], :langauge => request.env['HTTP_ACCEPT_LANGUAGE']).save
    rescue Exception => e
      puts "Unable to save PID access statistic: #{e.message}"                
    end
  end
  
end

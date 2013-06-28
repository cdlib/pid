require "net/http"

class PidApp < Sinatra::Application
  
  @@url_pattern = /https?:\/\/([A-Za-z0-9\-_:\.]+){2,6}(\/([A-Za-z0-9`~!@#\$%\^&\*\(\)\-_=\+\[{\]}\\\|;:'",\.\?]?)+){0,}(\.[A-Za-z0-9]+)?/
  
  get '/link/new' do
    erb :new_pid
  end
  
  post '/link' do
  	@successes = []
  	@failures = {}
  	
  	change_category = (request.referrer == '/new') ? 'User_Entered' : 'REST_API'
  	
  	params[:url].lines do |line|
  	
  		if line =~ @@url_pattern
  			url = line.strip.gsub("\r\n", "")
  			
  			unless url[-1] == "/"
  				url += "/"
  			end
  			
  			#Test to make sure this a valid URL
  			uri = URI.parse(url)
  			req = Net::HTTP.new(uri.host, uri.port)
  			res = req.request_head(uri.path)

  			if res.code.to_i < 300
  		
  				begin
  					pid = Pid.mint(:url => line.gsub("\r\n", ""), 
  												:username => 'placeholder', 
  												:change_category => change_category,
  												:notes => "Incoming request from #{request.ip} to mint #{line}")

						unless pid.nil? || !pid.valid?
				
					
							@successes << pid.id
						else
							@failures[url.to_s] = "Unable to save."
						end
					
  				rescue
  					@failures[url.to_s] = "Unable to save."
  				end
  				
				else
					@failures[line.gsub("\r\n", "")] = "Invalid URL."
				end
  		else
  			@failures[line.gsub("\r\n", "")] = "Invalid URL format."
  		end
  	end
    
		if @successes.empty?
    	return 500
    	
		elsif @successes.size == 1 && @failures.empty?
			redirect "/link/#{@successes[0]}"
		
		elsif @failures.size == 1 && @successes.empty?
			status 400
			erb :new_pid
		
		elsif @successes.size > 1 || @failures.size > 1
			@hostname = "#{request.scheme.to_s}://#{request.host.to_s}#{':' + request.port.to_s unless request.port.nil? }/link/"
			
			status 200
			erb :results_pid
		end
		
  end
  
  
  get '/link/:id' do
  
  	# To-Do: consider offloading this hard-coded '/PID/' to a config file or db table
  	@hostname = "#{request.scheme.to_s}://#{request.host.to_s}#{':' + request.port.to_s unless request.port.nil? }/PID/"
  	
    @pid = Pid.get(params[:id])
    
    if @pid
      erb :show_pid
    else
      404
    end
  end

end
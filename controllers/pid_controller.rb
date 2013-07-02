require "net/http"

class PidApp < Sinatra::Application
  
  @@url_pattern = /https?:\/\/([A-Za-z0-9\-_:\.]+){2,6}(\/([A-Za-z0-9`~!@#\$%\^&\*\(\)\-_=\+\[{\]}\\\|;:'",\.\?]?)+){0,}(\.[A-Za-z0-9]+)?/
  
# ---------------------------------------------------------------
# Display the new PID form
# ---------------------------------------------------------------  
  get '/link/new' do
    @failures = {}
    @successes = []
    erb :new_pid
  end
  
# ---------------------------------------------------------------
# Display the PIDs search form
# ---------------------------------------------------------------  
  get '/link/search' do
    @results = []
    erb :search_pid
  end
  
# ---------------------------------------------------------------
# Display the specified purl
# ---------------------------------------------------------------  
  get '/link/:id' do
    @pid = Pid.get(params[:id])
    
    @back_link = "/link"
    @back_label = "Home Page"
    
    if request.referrer == "#{hostname}link/new" 
      @back_link += "/new"
      @back_label = " New PID(s)"
    elsif request.referrer == "#{hostname}link/search"
      @back_link += "/search"
      @back_label = " Search"
    end

    if @pid
      erb :show_pid
    else
      404
    end
  end
  
# ---------------------------------------------------------------
# Display the main menu
# ---------------------------------------------------------------  
  get '/link' do
    erb :index
  end
  
# ---------------------------------------------------------------
# Process the PIDs search form
# ---------------------------------------------------------------  
  post '/link/search' do
    @results = []
    
    unless params.nil?
      args = {:limit => 50}
      
      unless params[:url].nil?
        args[:url.like] = '%' + params[:url] + '%'
      end
      
      @results = Pid.all(args)
      status 200
    end
    
    erb :search_pid
  end
  
# ---------------------------------------------------------------
# Process new PID requests
# ---------------------------------------------------------------
  post '/link' do
    @hostname = "#{request.scheme.to_s}://#{request.host.to_s}#{':' + request.port.to_s unless request.port.nil? }/link/"
    @successes = []
    @failures = {}
    
    change_category = (request.referrer == "#{hostname}link/new") ? 'User_Entered' : 'REST_API'
    
    params[:new_urls].lines do |line|
    
      url = line.strip.gsub("\r\n", "")
      
      unless url.empty?
        if url =~ @@url_pattern
        
          #unless url[-1] == "/"
          #	url += "/"
          #end
          
          # Temporarily uncomment. SCP not allowed by contract to check live URLs automatically
          # for all journals. Will happen while loading seed data, editing in masse.
          #Test to make sure this a valid URL
          # uri = URI.parse(url)
          # req = Net::HTTP.new(uri.host, uri.port)
          # res = req.request_head(uri.path)

          if true #res.code.to_i < 400
      
            begin
              pid = Pid.mint(:url => line.gsub("\r\n", ""), 
                             :username => 'placeholder', 
                             :change_category => change_category,
                             :notes => "Incoming request from #{request.ip} to mint #{line}")

              unless pid.nil? || !pid.valid?
                @successes << pid
              else
                @failures[url.to_s] = "Unable to save."
              end
              
            rescue Exception => e
              @failures[url.to_s] = "Unable to save #{e.message}"
            end
            
          else
            @failures[line.gsub("\r\n", "")] = "Invalid URL."
          end
        else
          @failures[line.gsub("\r\n", "")] = "Invalid URL format."
        end
        
      end  # end if empty
    end    # end loop
    
    if @failures.size >= 1
      status 400
      erb :new_pid
    elsif @successes.size >= 1
      status 200
      erb :new_pid
    else
      500
    end
  end
end
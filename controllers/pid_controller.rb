require "net/http"

class PidApp < Sinatra::Application
  
  @@url_pattern = /https?:\/\/([A-Za-z0-9\-_:\.]+){2,6}(\/([A-Za-z0-9`~!@#\$%\^&\*\(\)\-_=\+\[{\]}\\\|;:'",\.\?]?)+){0,}(\.[A-Za-z0-9]+)?/
  
  def verify_url(url)
    # SCP - not allowed by contract to check live URLs automatically
    # for all journals. Will happen while loading seed data, editing in masse.
      
    unless url[-1] == "/"
      url += "/"
    end
      
    #Test to make sure this a valid URL
    uri = URI.parse(url)
    req = Net::HTTP.new(uri.host, uri.port)
    res = req.request_head(uri.path)
      
    res.code.to_i
  end
    
    
  def mint_pid(new_url, referrer, username)
    change_category = (referrer == "#{hostname}link/new") ? 'User_Entered' : 'REST_API'
      
    url = new_url.strip.gsub("\r\n", "")
      
    unless url.empty?
      if url =~ @@url_pattern
      
        begin
          pid = Pid.mint(:url => url, 
                         :username => username,
                         :change_category => change_category,
                         :notes => "Incoming request from #{request.ip} to mint #{url}")
          
          {:code => 200, :message => pid}
          
        rescue Exception => e
          {:code => 500, :message => "Unable to create PID for #{url}.\n#{e.message}"}
        end
        
      else
        {:code => 400, :message => "Invalid URL format for #{url}"}
      end
      
    else
      {:code => 404, :message => "URL was empty #{url}"}
    end
      
  end
    
  def revise_pid(pid, params)
    unless pid.nil?
      begin
        pid.revise({:url => params[:url],
                    :deactivated => params[:active],
                    :maintainers =>  params[:maintainers]})
        
        {:code => 200, :message => "Your changes have been saved."}
        
      rescue Exception => e
        {:code => 500, :message => "Unable to save your changes.\n#{e.message}"}
      end
    else
      {:code => 404, :message => "No PID specified"}
    end
  end
  
  
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
# Display the reports page
# ---------------------------------------------------------------  
  get '/link/report' do
    erb :reports
  end

# ---------------------------------------------------------------
# Display the help page
# ---------------------------------------------------------------  
  get '/link/help' do
    erb :help
  end

# ---------------------------------------------------------------
# Display the edit page
# ---------------------------------------------------------------    
  get '/link/edit/:id' do
    @pid = Pid.get(params[:id])
    
    if !request.query_string.empty? && @pid
      erb :edit_pid, :layout => false
    elsif @pid
      erb :edit_pid
    else
      404
    end
  end
  
# ---------------------------------------------------------------
# Display the specified purl
# ---------------------------------------------------------------  
  get '/link/:id' do
    @pid = Pid.get(params[:id])
    
    if !request.query_string.empty? && @pid
      erb :show_pid, :layout => false
    elsif @pid
      erb :show_pid
    else
      404
    end
  end
  
# ---------------------------------------------------------------
# Display the main menu
# ---------------------------------------------------------------  
  ['/link/index', '/link', '/link/'].each do |path|
    get path do
      erb :index
    end
  end

  
# ---------------------------------------------------------------
# Process the PIDs search form
# ---------------------------------------------------------------  
  post '/link/search' do
    @results = []
    
    unless params.nil?
      args = {:limit => 100}
      
      unless params[:url].nil?
        args[:url.like] = '%' + params[:url] + '%'
      end
      
      @results = Pid.all(args)
      status 200
    end
    
    erb :search_pid
  end

# ---------------------------------------------------------------
# Edit PID(s)
# ---------------------------------------------------------------
  put '/link' do
  
    @pid = Pid.get(params[:pid])
    @message = "Unable to save your changes."
    
    params[:active] = (params[:active] == "on") ? false : true
    
    # To-Do parse out the maintainers param into an array
    params[:maintainers] = nil
    
    unless @pid.nil? 
      # Don't save if nothing has changed!
      if @pid.url != params[:url] || @pid.maintainers != params[:maintainers] || 
                                                   @pid.deactivated != params[:active] 
        resp = revise_pid(@pid, params)
        
        status resp[:code]
        @message = resp[:message]
      end
      
      #reload the pid before we pass it to the erb
      @pid = Pid.get(params[:pid])
      
      if !request.query_string.empty? && @pid
        erb :edit_pid, :layout => false
      elsif @pid
        erb :edit_pid
      end
    else
      @message = "PID #{params[:pid]} does not exist!"
      status 404
    end
  end
  
# ---------------------------------------------------------------
# Mint PID(s)
# ---------------------------------------------------------------
  post '/link' do
    fatal = false
    @successes = []
    @failures = {}
    
    params[:new_urls].lines do |line|
      resp = mint_pid(line, request.referrer, 'placeholder')
      
      if resp[:code] == 200
        @successes << resp[:message]
        
      elsif resp[:code] == 500
        fatal = true
      else
        @failures[line.strip] = resp[:message]
      end
    end
    
    if fatal                      # If any 500s were returned we should flag it with a 500
      response.status = 500
    elsif @failures.count > 0     # If we had at least one failure return a 400
      response.status = 400
    else                          # We had no failures 302 (per PURL spec for success minting)
      response.status = 302
    end
    
    erb :new_pid
  end
  
end
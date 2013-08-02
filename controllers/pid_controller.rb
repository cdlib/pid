require "net/http"

class PidApp < Sinatra::Application
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
    @users = (current_user.super) ? User.all(:order => [:login.asc]) : User.all(:group => current_user.group, :order => [:login.asc])
    
    if !Pid.first(:group => current_user.group).nil? || (current_user.super && !Pid.first().nil?)
      @pid_min = (current_user.super) ? Pid.first(:order => [:id.asc]).id : Pid.first(:group => current_user.group, :order => [:id.asc]).id
      @pid_max = (current_user.super) ? Pid.first(:order => [:id.desc]).id : Pid.first(:group => current_user.group, :order => [:id.desc]).id
    else
      @pid_min = 0
      @pid_max = 0
    end
    
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
# Display the specified purl
# ---------------------------------------------------------------  
  get '/link/:id' do
    @pid = Pid.get(params[:id])
    user = current_user
    
    if @pid
      if user.group == @pid.group || user.super
        @groups = Group.all if user.super
        @group = user.group

        erb :show_pid
        
      else
        401
      end
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
    user = current_user
    @results = []
    
    # Load the user list by the current user's group or everyone is they're a super admin
    @users = (user.super) ? User.all(:order => [:login.asc]) : User.all(:group => user.group, :order => [:login.asc])
    
    # Set the min and max PIDs for the range inputs (based on user's group unless they are a super admin)
    if !Pid.first(:group => user.group).nil? || (user.super && !Pid.first().nil?)
      @pid_min = (user.super) ? Pid.first(:order => [:id.asc]).id : Pid.first(:group => user.group, :order => [:id.asc]).id
      @pid_max = (user.super) ? Pid.first(:order => [:id.desc]).id : Pid.first(:group => user.group, :order => [:id.desc]).id
    else
      @pid_min = 0
      @pid_max = 0
    end
    
    # If either of the PID range values are empty set them to the limits
    params[:low] = @pid_min if params[:low].empty?
    params[:high] = @pid_max if params[:high].empty?
      
    # If the PID high range is less than the low range, swap them 
    params[:low], params[:high] = params[:high], params[:low] if params[:high] < params[:low]
      
    # Limit the search results based on the value in the config
    args = {:limit => HTML_CONFIG['search_results_limit'].to_i}
      
    # Set the search criteria based on the user's input
    args[:url.like] = '%' + params[:url] + '%' unless params[:url].empty?
    args[:username] = User.get(params[:userid]).login unless params[:userid].empty?
    args[:id.gte] = params[:low]
    args[:id.lte] = params[:high]
    args[:deactivated] = (params[:active] == '0') ? true : false
      
    if !params[:modified_low].empty?
      args[:modified_at.gte] = params[:modified_low] 
      args[:modified_at.lte] = params[:modified_high] ||= Time.now
    end
      
    # Filter the results to the user's group unless the user is an admin
    args[:group] = user.group unless user.super
      
    @results = Pid.all(args)
      
    status 404 if @results.empty?
    
    erb :search_pid
  end

# ---------------------------------------------------------------
# Edit PID
# ---------------------------------------------------------------
  put '/link/:id' do
    @pid = Pid.get(params[:id])
    user = current_user
    
    if @pid
      if @pid.group == user.group || user.super
        # Don't save if nothing has changed!
        if @pid.url != params[:url] || @pid.group.id != params[:group] || (@pid.deactivated != ((params[:active] == "on") ? false : true))
            
          begin
            @pid.revise({:url => (params[:active] == "on") ? params[:url] : "#{hostname()}link/dead", 
                         :deactivated => (params[:active] == "on") ? false : true,
                         :group =>  params[:group],
                         :username => user.login,
                         :modified_at => Time.now})
        
            @msg = MESSAGE_CONFIG['pid_update_success']
        
          rescue Exception => e
            @msg = MESSAGE_CONFIG['pid_update_failure'] 
            @msg += e.message
          end
        
        end
      
        @groups = Group.all if user.super
        @group = user.group
          
        #reload the pid before we pass it to the erb
        @pid = Pid.get(params[:id])
        erb :show_pid

        # User is not authorized to modify this PID!
      else
        401
        @msg = MESSAGE_CONFIG['pid_unauthorized']
      end
    else
      @msg = MESSAGE_CONFIG['pid_not_found']
      404
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
      
      change_category = (request.referrer == "#{hostname}link/new") ? 'User_Entered' : 'REST_API'
      notes = "Incoming request from #{request.ip} to mint #{url}" if request.referrer != "#{hostname}link/new"
      
      url = line.strip.gsub("\r\n", '').gsub("\n", '')
      
      unless url.empty?
        if url =~ URI_REGEX
      
          begin
            pid = Pid.mint(:url => url, 
                           :username => current_user.login,
                           :group => current_user.group,
                           :change_category => change_category,
                           :notes => notes)
            @successes << pid
          
          rescue Exception => e
            fatal = true
            @failures[line.strip] = "Unable to create PID for #{url}. #{e.message}"
          end
        
        else
          @failures[line.strip] = "Invalid URL format for #{url}"
        end
      
      else
        @failures[line.strip] = "URL was empty #{url}"
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

# ---------------------------------------------------------------
# Verify the URL by doing a GET - for future use
# ---------------------------------------------------------------  
  before '/link' do
    redirect '/user/login', {:msg => MESSAGE_CONFIG['session_expired']} unless logged_in?
  end
  
  before '/link/*' do
    redirect '/user/login', {:msg => MESSAGE_CONFIG['session_expired']} unless logged_in?
  end
  
  
# ---------------------------------------------------------------
# Verify the URL by doing a GET - for future use
# ---------------------------------------------------------------  
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
    
# ---------------------------------------------------------------
# Performs the mint and interprets the results for the route
# ---------------------------------------------------------------  
  def mint_pid(new_url, referrer, user)
    change_category = (referrer == "#{hostname}link/new") ? 'User_Entered' : 'REST_API'
      
    url = new_url.strip.gsub("\r\n", '').gsub("\n", '')
      
    unless url.empty?
      if url =~ @@url_pattern
      
        begin
          pid = Pid.mint(:url => url, 
                         :username => user.login,
                         :group => user.group,
                         :change_category => change_category,
                         :notes => "Incoming request from #{request.ip} to mint #{url}")
          
          {:code => 200, :message => pid}
          
        rescue Exception => e
          {:code => 500, :message => "Unable to create PID for #{url}. #{e.message}"}
        end
        
      else
        {:code => 400, :message => "Invalid URL format for #{url}"}
      end
      
    else
      {:code => 404, :message => "URL was empty #{url}"}
    end
      
  end

end
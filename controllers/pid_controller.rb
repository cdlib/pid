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
    @defaults = get_search_defaults
    
    @users = @defaults[:users]
    @pid_min = @defaults[:pid_min]
    @pid_max = @defaults[:pid_max]
    
    params[:pid_low] ||= @defaults[:pid_min]
    params[:pid_high] ||= @defaults[:pid_max]
    
    params[:created_low] ||= @defaults[:created_low]
    params[:created_high] ||= @defaults[:created_high]
    params[:modified_low] ||= @defaults[:modified_low]
    params[:modified_high] ||= @defaults[:modified_high]
    
    erb :search_pid
  end
  
# ---------------------------------------------------------------
# Display the batch edit page
# ---------------------------------------------------------------  
  get '/link/edit' do
    @failures = [] 
    @mints = [] 
    @revisions = []
    
    erb :edit_pid
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

        if params[:ajax] == "true"
          erb :edit_pid_form, :layout => false
        else
          erb :show_pid
        end

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
  post '/link/edit' do
    @msg = ''
    @failures = [] 
    @mints = []
    @revisions = []
    
    if !params[:csv].empty?
      if params[:csv][:type] == 'text/csv'

        begin
          # Loop through the items in the CSV
          CSV.foreach(params[:csv][:tempfile]) do |row| 
            id, url, cat, note = row
          
            # If the PID id is null they would like to mint the PID
            if id.nil?
              # Make sure the URL is not missing
              if !url.nil?
                begin
                  pid = Pid.mint(:url => url, 
                                 :username => current_user.login,
                                 :group => current_user.group,
                                 :change_category => cat,
                                 :notes => note)

                  @mints << pid
                rescue Exception => e
                  @failures << "#{MESSAGE_CONFIG['batch_process_mint_failure'].gsub('{?}', id)} #{e.message}"
                end
              else
                @failures << MESSAGE_CONFIG['batch_process_mint_inactive']
              end
            
            # We are updating an existing PID
            else
              pid = Pid.get(id)
          
              # If the PID was found and its in the same group as the user or the user is an admin
              if !pid.nil?

                if pid.group == current_user.group || current_user.super
                  begin 
                    pid.revise({:url => url.nil? ? pid.url : url, 
                                :change_category => cat,
                                :notes => note,
                                :deactivated => url.nil? ? true : false,
                                :group =>  current_user.group,
                                :username => current_user.login,
                                :modified_at => Time.now,
                                :dead_pid_url => "#{hostname}link/dead"})
                             
                    @revisions << Pid.get(pid.id)
                  rescue Exception => e
                    @failures << "#{MESSAGE_CONFIG['batch_process_revise_failure'].gsub('{?}', id)} #{e.message}"
                  end
                else
                  @failures << MESSAGE_CONFIG['batch_process_revise_wrong_group'].gsub('{?}', id)
                end
              else
                @failures << MESSAGE_CONFIG['batch_process_revise_missing'].gsub('{?}', '')
              end
            end
          
          end
        
          @msg = MESSAGE_CONFIG['batch_process_success']
        rescue Exception => e
          @msg = "#{MESSAGE_CONFIG['batch_process_failure']}<br /><br />#{e.message}"
        end

      else
        @msg = MESSAGE_CONFIG['invalid_file_type']
      end
    else
      @msg = MESSAGE_CONFIG['no_file_selected']
    end

    erb :edit_pid
  end

# ---------------------------------------------------------------
# Process the PIDs search form
# ---------------------------------------------------------------  
  post '/link/search' do
    @results = []
    @defaults = get_search_defaults
    
    @users = @defaults[:users]
    @pid_min = @defaults[:pid_min]
    @pid_max = @defaults[:pid_max]

    # If either of the PID range values are empty set them to the limits
    params[:pid_low] = @defaults[:pid_min] if (params[:pid_low].nil? ? true : params[:pid_low].empty?)
    params[:pid_high] = @defaults[:pid_max] if (params[:pid_high].nil? ? true : params[:pid_high].empty?)
    
    # If the date ranges are empty set them to the limits
    params[:created_low] = @defaults[:created_low] if (params[:created_low].nil? ? true : params[:created_low].empty?)
    params[:created_high] = @defaults[:created_high] if (params[:created_high].nil? ? true : params[:created_high].empty?)
    params[:modified_low] = @defaults[:modified_low] if (params[:modified_low].nil? ? true : params[:modified_low].empty?)
    params[:modified_high] = @defaults[:modified_high] if (params[:modified_high].nil? ? true : params[:modified_high].empty?)
      
    # If the PID high range is less than the low range, swap them 
    params[:pid_low], params[:pid_high] = params[:pid_high], params[:pid_low] if params[:pid_high] < params[:pid_low]
      
    # Limit the search results based on the value in the config
    args = {:limit => APP_CONFIG['search_results_limit'].to_i}
      
    # Set the search criteria based on the user's input
    args[:url.like] = '%' + params[:url] + '%' unless params[:url].empty?
    args[:username] = User.get(params[:userid]).login unless params[:userid].empty?
    
    args[:deactivated] = (params[:active] == '0') ? true : false unless params[:active].empty?
      
    args[:id.gte] = params[:pid_low]
    args[:id.lte] = params[:pid_high]
    
    args[:modified_at.gte] = "#{params[:modified_low]} 00:00:00"
    args[:modified_at.lte] = "#{params[:modified_high]} 23:59:59"
    
    args[:created_at.gte] = "#{params[:created_low]} 00:00:00" 
    args[:created_at.lte] = "#{params[:created_high]} 23:59:59"
    
    # Filter the results to the user's group unless the user is an admin
    args[:group] = current_user.group unless current_user.super
      
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
            @pid.revise({:url => params[:url], 
                         :deactivated => (params[:active] == "on") ? false : true,
                         :group =>  params[:group],
                         :username => user.login,
                         :modified_at => Time.now,
                          :dead_pid_url => "#{hostname}link/dead"})
        
            # Check to see if the PID's URL is valid, if not WARN the user
            if verify_url(url) != 200
              @msg = MESSAGE_CONFIG['pid_revise_dead_url'].gsub('{?}', @pid.id) 
            else
              @msg = MESSAGE_CONFIG['pid_update_success']
            end
            
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
      notes = MESSAGE_CONFIG['pid_mint_default_note'].gsub('{?ip?}', request.ip).gsub('{?}', url) if request.referrer != "#{hostname}link/new"
      
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
          
            # Check to see if the PID's URL is valid, if not WARN the user
            @failures[line.strip] = MESSAGE_CONFIG['pid_mint_dead_url'].gsub('{?}', pid.id.to_s) if verify_url(url) != 200

          rescue Exception => e
            fatal = true 
            @failures[line.strip] = "#{MESSAGE_CONFIG['pid_mint_failure'].gsub('{?}', url)} - #{e.message}"
          end
        
        else
          @failures[line.strip] = MESSAGE_CONFIG['pid_mint_invalid_url'].gsub('{?}', url) 
        end
      
      else
        @failures[line.strip] = MESSAGE_CONFIG['pid_mint_empty_url']
      end
      
    end
    
    if fatal                      # If any 500s were returned we should flag it with a 500
      response.status = 500
    elsif @failures.count - @successes.count > 0     # If we had at least one failure return a 400 (inactive URLs are in here so check against success count!)
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
    
    
private
  def get_search_defaults 
    group = current_user.group 
    super_user = current_user.super
    
    defaults = {:pid_min => 0, :pid_max => 0, :modified_low => '', :modified_high => '', :created_low => '', :created_high => ''}
    
    defaults[:users] = (super_user) ? User.all(:order => [:login.asc]) : User.all(:group => group, :order => [:login.asc])
    
    # If the group (or system in the case of a super user) has PIDs find the first and last otherwise default to generic values
    if !Pid.first(:group => group).nil? || (super_user && !Pid.first().nil?)
      if super_user
        defaults[:pid_min] = Pid.first(:order => [:id.asc]).id
        defaults[:pid_max] = Pid.first(:order => [:id.desc]).id
        defaults[:modified_low] = Pid.first(:order => [:modified_at.asc]).modified_at.strftime("%Y-%m-%d")
        defaults[:modified_high] = Pid.first(:order => [:modified_at.desc]).modified_at.strftime("%Y-%m-%d")
        defaults[:created_low] = Pid.first(:order => [:created_at.asc]).created_at.strftime("%Y-%m-%d")
        defaults[:created_high] = Pid.first(:order => [:created_at.desc]).created_at.strftime("%Y-%m-%d")
      else
        defaults[:pid_min] = Pid.first(:group => group, :order => [:id.asc]).id
        defaults[:pid_max] = Pid.first(:group => group, :order => [:id.desc]).id
        defaults[:modified_low] = Pid.first(:group => group, :order => [:modified_at.asc]).modified_at.strftime("%Y-%m-%d")
        defaults[:modified_high] = Pid.first(:group => group, :order => [:modified_at.desc]).modified_at.strftime("%Y-%m-%d")
        defaults[:created_low] = Pid.first(:group => group, :order => [:created_at.asc]).created_at.strftime("%Y-%m-%d")
        defaults[:created_high] = Pid.first(:group => group, :order => [:created_at.desc]).created_at.strftime("%Y-%m-%d")
      end
    end
    
    
    defaults
  end

end
class PidApp < Sinatra::Application
  
# ---------------------------------------------------------------
# Get the list of inactive PIDs
# ---------------------------------------------------------------
  get '/report/inactive' do
    @results = []
    
    begin
      # If the user is a super user, get all of the inactive PIDs otherwise just the ones for their group
      if current_user.super
        @results = Pid.all(:deactivated => true)
      else
        @results = Pid.all(:deactivated => true, :group => current_user.group)
      end
      
    rescue Exception => e
      @msg = "#{MESSAGE_CONFIG['reports_failure']} - #{e.message}"
    end
    
    erb :report_inactive
  end

# ---------------------------------------------------------------
# Get the list of PIDs with invalid URLs
# ---------------------------------------------------------------
  get '/report/invalid' do
    @moved = []
    @not_found = []
    @error = []
    
    begin
      # If the user is a super user, get all of the PIDs otherwise just the ones for their group
      if current_user.super
        pids = Pid.all(:deactivated => false)
      else
        pids = Pid.all(:group => current_user.group, :deactivated => false)
      end
      
      pids.each do |pid|
        
        # Check the URLs for each of the PIDs
        case verify_url(pid.url).to_i
        when 300..399
          @moved << pid
        when 400..499
          @not_found << pid
        when 500..999
          @error << pid
        end
        
      end
      
    rescue Exception => e
      @msg = "#{MESSAGE_CONFIG['reports_failure']} - #{e.message}"
    end
    
    erb :report_invalid
  end
  
# ---------------------------------------------------------------
# Get a list of duplicate PIDs
# ---------------------------------------------------------------
  get '/report/duplicate' do
    @results = {}
    
puts "Starting duplicate report - #{Time.now}"
    
    begin
      dups = Duplicate.all
      
      dups.each do |dup|
        if current_user.super
          pids = Pid.all(:deactivated => false, :url => dup.url)
        else
          pids = Pid.all(:deactivated => false, :group => current_user.group, :url => dup.url)
        end
        
        if pids.count > 1
          vals = ""
          pids.each do |pid|
            vals += "#{pid.id},"
          end
          @results[dup.url] = vals
        end
      end        
        
      # If the user is a super user, get all of the PIDs otherwise just the ones for their group
      #if current_user.super
        #pids = Pid.all(:deactivated => false)
      #else
        #pids = Pid.all(:group => current_user.group, :deactivated => false)
      #end
      
      #pids.each do |pid|
        #@results[pid.url] = "#{@results[pid.url]} #{pid.id}," if Pid.all(:url => pid.url, :deactivated => false).count > 1
      #end
      
    rescue Exception => e
      @msg = "#{MESSAGE_CONFIG['reports_failure']} - #{e.message}"
    end
    
puts "Ending duplicate report - #{Time.now}"
    
    erb :report_duplicate
    
  end
  
# ---------------------------------------------------------------
# Get the stats report page
# ---------------------------------------------------------------
  get '/report/stats' do
    @results = []
    @defaults = get_search_defaults
    
    @users = @defaults[:users]
    
    params[:created_low] ||= @defaults[:created_low]
    params[:created_high] ||= @defaults[:created_high]
    params[:modified_low] ||= @defaults[:modified_low]
    params[:modified_high] ||= @defaults[:modified_high]
    
    erb :report_stats
  end
  
# ---------------------------------------------------------------
# Process the stats report
# ---------------------------------------------------------------
  post '/report/stats' do
    @results = []
    @defaults = get_search_defaults
    
    @users = @defaults[:users]
    
    # If the date ranges are empty set them to the limits
    params[:created_low] = @defaults[:created_low] if (params[:created_low].nil? ? true : params[:created_low].empty?)
    params[:created_high] = @defaults[:created_high] if (params[:created_high].nil? ? true : params[:created_high].empty?)
    params[:modified_low] = @defaults[:modified_low] if (params[:modified_low].nil? ? true : params[:modified_low].empty?)
    params[:modified_high] = @defaults[:modified_high] if (params[:modified_high].nil? ? true : params[:modified_high].empty?)
      
    args = {}
      
    # Set the search criteria based on the user's input
    args[:url.like] = '%' + params[:url] + '%' unless params[:url].empty?
    args[:username] = User.get(params[:userid]).login unless params[:userid].empty?
    
    args[:modified_at.gte] = "#{params[:modified_low]} 00:00:00"
    args[:modified_at.lte] = "#{params[:modified_high]} 23:59:59"
    
    args[:created_at.gte] = "#{params[:created_low]} 00:00:00" 
    args[:created_at.lte] = "#{params[:created_high]} 23:59:59"
    
    # Filter the results to the user's group unless the user is an admin
    args[:group] = current_user.group unless current_user.super
      
    pids = Pid.all(args)
      
    pids.each do |pid|
      @results << {:id => pid.id, :url => pid.url, :username => pid.username, :created_at => pid.created_at, :modified_at => pid.modified_at,
                  :notes => pid.notes, :change_category => pid.change_category, :deactivated => pid.deactivated,
                  :versions => PidVersion.all(:pid => pid, :created_at.gte => "#{params[:modified_low]} 00:00:00",
                                              :created_at.lte => "#{params[:modified_high]} 23:59:59", :order => [:created_at.desc])}
    end
      
    status 404 if @results.empty?
    
    erb :report_stats
  end
  
# ---------------------------------------------------------------
# Verify that the user is logged in before allowing access to a report
# ---------------------------------------------------------------
  before '/report/*' do
    redirect '/user/login', {:msg => MESSAGE_CONFIG['session_expired']} unless logged_in?
  end

# ---------------------------------------------------------------
# Verify the URL by doing a GET - for future use
# ---------------------------------------------------------------  
private
    def verify_url(url)
      # SCP - not allowed by contract to check live URLs automatically
      # for all journals. Will happen while loading seed data, editing in masse.
      
      #Test to make sure this a valid URL
      uri = URI.parse(url)
      req = Net::HTTP.new(uri.host, uri.port)
      res = req.request_head(uri.path)
            
      res.code.to_i
      
    end

end
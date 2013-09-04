require 'json'

class PidApp < Sinatra::Application
# ---------------------------------------------------------------
# Get the list of inactive PIDs
# ---------------------------------------------------------------
  get '/report/inactive' do
    pids = []
    
    begin
      # If the user is a super user, get all of the inactive PIDs otherwise just the ones for their group
      if current_user.super
        pids = Pid.all(:deactivated => true)
        
      # If the user manages groups show the pids for all of those groups
      elsif !Maintainer.all(:user => current_user).empty?
        Maintainer.all(:user => current_user).each do |maintainer|  
          (Pid.all(:deactivated => true) & Pid.all(:group => maintainer.group)).each{ |pid| pids << pid } 
        end
        
      else
        pids = Pid.all(:deactivated => true, :group => current_user.group)
      end
      
    rescue Exception => e
      @msg = "#{MESSAGE_CONFIG['reports_failure']} - #{e.message}"
    end

    puts pids.inspect

    @json = pids.to_json

    erb :report_inactive
  end

# ---------------------------------------------------------------
# Get the list of PIDs with invalid URLs
# ---------------------------------------------------------------
  get '/report/invalid' do
    pids = []
    moved = []
    not_found = []
    error = []
    @msg = ""
    
    begin
      # If the user is a super user, get all of the PIDs otherwise just the ones for their group
      if current_user.super
        pids = Pid.all(:deactivated => false)
        
      # If the user manages groups show the pids for all of those groups
      elsif !Maintainer.all(:user => current_user).empty?
        Maintainer.all(:user => current_user).each do |maintainer| 
          (Pid.all(:deactivated => true) & Pid.all(:group => maintainer.group)).each{ |pid| pids << pid } 
        end
          
      else
        pids = Pid.all(:group => current_user.group, :deactivated => false)
      end
      
      pids.each do |pid|
        
        begin
          # Check the URLs for each of the PIDs
          case verify_url(pid.url).to_i
          when 300..399
            moved << pid
          when 400..499
            not_found << pid
          when 500..999
            error << pid
          end
          
        rescue Exception => e
          error << pid
        end
      end
      
    rescue Exception => e
      @msg += "#{MESSAGE_CONFIG['reports_failure']} - #{e.message}"
    end
    
    @moved = moved.to_json
    @not_found = not_found.to_json
    @error = error.to_json
    
    erb :report_invalid
  end
  
# ---------------------------------------------------------------
# Get a list of duplicate PIDs
# ---------------------------------------------------------------
  get '/report/duplicate' do
    
    begin
      shorty = Shortcake.new('pid', {:host => 'localhost', :port => 6379})
      
      if current_user.super
        pids = Pid.all(:deactivated => false)
        
      # If the user manages groups show the pids for all of those groups
      elsif !Maintainer.all(:user => current_user).empty?
        Maintainer.all(:user => current_user).each do |maintainer| 
          (Pid.all(:deactivated => true) & Pid.all(:group => maintainer.group)).each{ |pid| pids << pid } 
        end
          
      else
        pids = Pid.all(:deactivated => false, :group => current_user.group)
      end
      
      dups = {}
      
      pids.each do |pid|
        if dups[pid.url].nil?
          occurences = shorty.get(pid.url)        
        
          if occurences
            vals = JSON.parse(occurences)
            if vals.size > 1
              dups[pid.url] = vals
            end
          end
        end
      end
      
    rescue Exception => e
      @msg = "#{MESSAGE_CONFIG['reports_failure']} - #{e.message}"
    end
    
    @json = dups.to_json
    
    erb :report_duplicate
    
  end
  
# ---------------------------------------------------------------
# Get the stats report page
# ---------------------------------------------------------------
  get '/report/stats' do
    @json = [].to_json
    @params = get_search_defaults(params)
    
    erb :report_stats
  end
  
# ---------------------------------------------------------------
# Process the stats report
# ---------------------------------------------------------------
  post '/report/stats' do
    results = []
    @params = get_search_defaults(params)
    
    args = {}
      
    # Set the search criteria based on the user's input
    args[:url.like] = '%' + @params[:url] + '%' unless @params[:url].empty?
    args[:username] = User.get(@params[:userid]).login unless @params[:userid].empty?
    
    args[:modified_at.gte] = "#{@params[:modified_low]} 00:00:00"
    args[:modified_at.lte] = "#{@params[:modified_high]} 23:59:59"
    
    args[:created_at.gte] = "#{@params[:created_low]} 00:00:00" 
    args[:created_at.lte] = "#{@params[:created_high]} 23:59:59"
    
    # Filter the results to the user's group unless the user is an admin
    if !current_user.super
      args[:group] = current_user.group 
    
    # If the user manages groups show the pids for all of those groups
    elsif !Maintainer.all(:user => current_user).empty?
      Maintainer.all(:user => current_user).each do |maintainer| 
        (Pid.all(:deactivated => true) & Pid.all(:group => maintainer.group)).each{ |pid| pids << pid } 
      end
    end
    
    pids = Pid.all(args)
      
    pids.each do |pid|
      results << {:id => pid.id, :url => pid.url, :username => pid.username, :created_at => pid.created_at, :modified_at => pid.modified_at,
                  :notes => pid.notes, :change_category => pid.change_category, :deactivated => pid.deactivated,
                  :versions => PidVersion.all(:pid => pid, :created_at.gte => "#{params[:modified_low]} 00:00:00",
                                              :created_at.lte => "#{params[:modified_high]} 23:59:59", :order => [:created_at.desc])}
    end
      
    @json = results.to_json
    404 if results.empty?
    
    erb :report_stats
  end

# ---------------------------------------------------------------
# Reload the default criteria for the reports
# ---------------------------------------------------------------
  get '/report/defaults' do
    get_search_defaults({}).to_json 
  end
  
# ---------------------------------------------------------------
# Verify that the user is logged in before allowing access to a report
# ---------------------------------------------------------------
  before '/report/*' do
    redirect '/user/login', {:msg => MESSAGE_CONFIG['session_expired']} unless logged_in?
  end

end
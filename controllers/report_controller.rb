require 'json'

class PidApp < Sinatra::Application
  
# ---------------------------------------------------------------
# Display the reports page
# ---------------------------------------------------------------  
  get '/report' do
    erb :reports
  end
    
# ---------------------------------------------------------------
# Get the list of inactive PIDs
# ---------------------------------------------------------------
  get '/report/inactive' do
    pids = []
    
    @groups = Group.all
    @json = [].to_json
    @msg = ""
    
    erb :report_inactive
  end
    
# ---------------------------------------------------------------
# Get the list of inactive PIDs for the group specified
# ---------------------------------------------------------------
  post '/report/inactive' do
    begin
      args = {:group => Group.first(:id => params[:groupid]), :deactivated => true }
      args[:modified_at.gte] = "#{params[:modified_low]} 00:00:00" unless params[:modified_low].empty?
      
      pids = Pid.all(args)
      
    rescue Exception => e
      @msg = "#{MESSAGE_CONFIG['reports_failure']} - #{e.message}"
      
      @msg += " - #{e.message}" if current_user.super
      
      logger.error "#{current_user.login} - #{@msg}: #{e.message}"
    end

    @groups = Group.all
    
    @json = pids.to_json

    erb :report_inactive
  end

# ---------------------------------------------------------------
# Get the invalid URL report
# ---------------------------------------------------------------
  get '/report/invalid' do
    @moved = [].to_json
    @not_found = [].to_json
    @error = [].to_json
    
    @groups = Group.all
    @skips = SkipCheck.all()
    
    @msg = ""

    erb :report_invalid
  end
  
# ---------------------------------------------------------------
# Get the list of PIDs with invalid URLs for the specified group
# ---------------------------------------------------------------
  post '/report/invalid' do
    pids = []
    moved = []
    not_found = []
    error = []
    @msg = ""
    
    begin
      
      pids = Pid.all(:group => Group.first(:id => params[:groupid]), :invalid_url_report.not => nil)
      
      pids.each do |pid|
        
        begin      
          if !pid.invalid_url_report.nil?    
            
            # Check the URLs for each of the PIDs
            case pid.invalid_url_report.http_code
            when 300..399
              moved << pid
            when 400..499
              not_found << pid
            when 500..999
              error << pid
            end
          end
          
        rescue Exception => e
          error << pid
        end
      end
      
    rescue Exception => e
      @msg += "#{MESSAGE_CONFIG['reports_failure']} - #{e.message}"
      
      @msg += " - #{e.message}" if current_user.super
      
      logger.error "#{current_user.login} - #{@msg}: #{e.message}"
    end
    
    @moved = moved.to_json
    @not_found = not_found.to_json
    @error = error.to_json
    
    @groups = Group.all
    @skips = SkipCheck.all()
    
    erb :report_invalid
  end
  
# ---------------------------------------------------------------
# Get a list of duplicate PIDs
# ---------------------------------------------------------------
  get '/report/duplicate' do
    @json = {}.to_json
    @msg = ""
    @groups = Group.all
    
    erb :report_duplicate
  end

# ---------------------------------------------------------------
# Get a list of duplicate PIDs for the specified group
# ---------------------------------------------------------------
  post '/report/duplicate' do
    pids = []
    
    begin
      
      pids = Pid.all(:group => Group.first(:id => params[:groupid]), :duplicate_url_report.not => nil)
      
      dups = {}
      
      pids.each do |pid|
        dups[pid.url] = pid.duplicate_url_report.other_pids unless pid.duplicate_url_report.nil?
      end
      
    rescue Exception => e
      @msg = "#{MESSAGE_CONFIG['reports_failure']}"
      @msg += " - #{e.message}" if current_user.super
      
      logger.error "#{current_user.login} - #{@msg}: #{e.message}"
    end
    
    @json = dups.to_json
    @groups = Group.all
    
    erb :report_duplicate
  end
  
# ---------------------------------------------------------------
# Get the stats report page
# ---------------------------------------------------------------
  get '/report/stats' do
    @json = [].to_json

    erb :report_stats
  end
  
# ---------------------------------------------------------------
# Process the stats report
# ---------------------------------------------------------------
  post '/report/stats' do
    results = []
    
    start_date = params[:start_date].empty? ? nil : "#{params[:start_date]} 00:00:00"
    end_date = params[:end_date].empty? ? "#{Time.now.to_s}" : "#{params[:end_date]} 23:59:59"
    
    if !start_date.nil?
      Group.all.each do |group|
        results << {:group => group.id,
                    :modified => Pid.all(:group => group, :modified_at.gte => start_date, :modified_at.lte => end_date).count,
                    :created => Pid.all(:group => group, :created_at.gte => start_date, :created_at.lte => end_date).count,
                    :deactivated => Pid.all(:group => group, :modified_at.gte => start_date, :modified_at.lte => end_date, :deactivated => true).count
                  }
      end
      
    end
    
    @json = results.to_json
    
    erb :report_stats
  end

# ---------------------------------------------------------------
# Get the modification details report
# ---------------------------------------------------------------
  get '/report/mods' do
    @json = [].to_json
    @groups = Group.all
    
    erb :report_mods
  end
  
# ---------------------------------------------------------------
# Get the modification details report for the specified criteria
# ---------------------------------------------------------------
  post '/report/mods' do
    results = []
    
    start_date = params[:start_date].empty? ? nil : "#{params[:start_date]} 00:00:00"
    end_date = params[:end_date].empty? ? "#{Time.now.to_s}" : "#{params[:end_date]} 23:59:59"
    
    if !start_date.nil?
      pids = Pid.all(:group => Group.first(:id => params[:groupid]), :modified_at.gte => start_date, :modified_at.lte => end_date)
      
      pids.each do |pid|
        prior = pid.pid_versions[pid.pid_versions.length - 2]
        
        # Skip items that only had their note changed!
        if pid.url != prior.url or pid.deactivated != prior.deactivated or pid.group != prior.group
          
          types = ""
          types = 'URL change<br />' if pid.url != prior.url
          types += "Moved from group #{prior.group}<br/>" if pid.group.id != prior.group
          types += 'deactivation' if (pid.deactivated != prior.deactivated) and pid.deactivated
          
          # If there is only 1 version then this was minted during the time period specified
          types = 'minted' if pid.pid_versions.length == 1
          
          results << {:id => pid.id,
                      :modified_on => pid.modified_at,
                      :username => pid.username,
                      :types =>  types,
                      :current_url => pid.url,
                      :prior_url => prior.url,
                      :active => (pid.deactivated) ? 'No' : 'Yes'}
        end
      end
      
    end
    
    @json = results.to_json
    @groups = Group.all
    
    erb :report_mods
  end
  

# ---------------------------------------------------------------
# Reload the default criteria for the reports
# ---------------------------------------------------------------
  get '/report/defaults' do
    get_search_defaults({}).to_json 
  end

# --------------------------------------------------------------------------------------------------------------
  before '/report' do
    halt(401) unless logged_in?
    
    # If the user has a readonly account prevent them accessing anything
    halt(403) if current_user.read_only
  end
      
# --------------------------------------------------------------------------------------------------------------
  before '/report/*' do
    halt(401) unless logged_in?
    
    # If the user has a readonly account prevent them accessing anything
    halt(403) if current_user.read_only
  end
  
end
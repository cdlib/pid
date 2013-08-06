class ReportApp < Sinatra::Application
  
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
      @msg = "#{MESSAGE_CONFIG['reports_inactive_failure']} - #{e.message}"
    end
    
    erb :report
  end

# ---------------------------------------------------------------
# Get the list of PIDs with invalid URLs
# ---------------------------------------------------------------
  get '/report/invalid' do
    
  end
  
# ---------------------------------------------------------------
# Get a list of duplicate PIDs
# ---------------------------------------------------------------
  get '/report/duplicate' do
    
  end
  
# ---------------------------------------------------------------
# Get the stats report page
# ---------------------------------------------------------------
  get '/report/stats' do
    
  end
  
# ---------------------------------------------------------------
# Process the stats report
# ---------------------------------------------------------------
  post '/report/stats' do
    
  end
  
# ---------------------------------------------------------------
# Verify that the user is logged in before allowing access to a report
# ---------------------------------------------------------------
  before '/report/*' do
    redirect '/user/login', {:msg => MESSAGE_CONFIG['session_expired']} unless logged_in?
  end
  
end
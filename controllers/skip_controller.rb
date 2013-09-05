class PidApp < Sinatra::Application
# ---------------------------------------------------------------
# Display the list of Domains that cannot have their urls checked
# ---------------------------------------------------------------  
  get '/skip' do
    @skips = SkipCheck.all()
    
    erb :list_skips
  end
  
# ---------------------------------------------------------------
# Add the specified domain
# ---------------------------------------------------------------  
  post '/skip' do
    begin
      exists = false
      
      # If the domain specified is already a part of another skip check or another skip check contains the specified domain 
      SkipCheck.all().each{ |it| exists = true if params[:domain].downcase.include?(it.domain) || it.domain.include?(params[:domain].downcase) }

      if !exists
        SkipCheck.new(:domain => params[:domain].downcase, :created_at => Time.now, :group => current_user.group.id).save
        
        @msg = MESSAGE_CONFIG['skip_success']  
      else
        @msg = MESSAGE_CONFIG['skip_duplicate']
      end
      
    rescue Exception => e
      @msg = MESSAGE_CONFIG['skip_failure'] + e.message
    end
    
    @skips = SkipCheck.all()
    
    erb :list_skips
  end
  
# ---------------------------------------------------------------
# Delete the specified domain
# ---------------------------------------------------------------  
  delete '/skip' do
    skip = SkipCheck.first(:domain => params[:domain].downcase)
    
    if !skip.nil?
      
      # If the domain belongs to the current user's group or the current user maintains the group that the skip belongs to.
      if skip.group == current_user.group || Maintainer.first(:user => current_user.login, :group => skip.group) || current_user.super
        skip.destroy
      
        @msg = MESSAGE_CONFIG['skip_delete'] 
      else
        @msg = MESSAGE_CONFIG['skip_not_authorized'] 
      end
    else
      @msg = MESSAGE_CONFIG['skip_failure']
    end
      
    @skips = SkipCheck.all()
    
    erb :list_skips
  end
  
# --------------------------------------------------------------------------------------------------------------
# Redirect to the login if the user isn't authenticated 
# Redirect to the unauthorized page if the user is not a maintainer of a group
# --------------------------------------------------------------------------------------------------------------
  before '/skip' do
    redirect '/user/login', {:msg => MESSAGE_CONFIG['session_expired']} unless logged_in?
    erb :unauthorized if Maintainer.first(:user => current_user).nil? && !current_user.super
  end 
  
end
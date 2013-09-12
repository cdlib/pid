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
    exists = false
      
    # If the domain specified is already a part of another skip check or another skip check contains the specified domain 
    SkipCheck.all().each do |it| 
      exists = true if params[:domain].downcase.include?(it.domain) or it.domain.include?(params[:domain].downcase) 
    end

    if !exists
      begin
        SkipCheck.new(:domain => params[:domain].downcase, :created_at => Time.now, :group => current_user.group.id).save
          
        @msg = MESSAGE_CONFIG['skip_success']  
      rescue Exception => e
        status 500
        @msg = MESSAGE_CONFIG['skip_failure']
      end
    else
      status 500
      @msg = MESSAGE_CONFIG['skip_duplicate']
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
      if skip.group == current_user.group.id or !Maintainer.first(:user => current_user.login, :group => skip.group).nil? or current_user.super
        begin
          skip.destroy
          
          @msg = MESSAGE_CONFIG['skip_delete'] 
        rescue Exception => e
          status 500
          @msg = MESSAGE_CONFIG['skip_failure']
        end
      else
        halt(403)
      end
      
      @skips = SkipCheck.all()
    
      @msg if request.xhr?
      erb :list_skips unless request.xhr?
    else
      halt(404)
    end
  end
  
# --------------------------------------------------------------------------------------------------------------


# --------------------------------------------------------------------------------------------------------------
  before '/skip' do
    halt(401) unless logged_in?

    # If the user is not a maintainer/manager of a group
    halt(403) if Maintainer.first(:user => current_user).nil? and !current_user.super
  end 
  
# --------------------------------------------------------------------------------------------------------------
  after '/group/*' do
    session[:msg] = nil
  end

# --------------------------------------------------------------------------------------------------------------
  not_found do
    @msg = MESSAGE_CONFIG['skip_not_found']
    @msg if request.xhr?
    erb :not_found unless request.xhr?
  end

# --------------------------------------------------------------------------------------------------------------
  error 401 do
    erb :login
  end
    
# --------------------------------------------------------------------------------------------------------------
  error 403 do
    @msg = MESSAGE_CONFIG['skip_unauthorized']
    response.body = @msg if request.xhr?
    erb :unauthorized unless request.xhr?
  end
  
end
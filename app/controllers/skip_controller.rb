class PidApp < Sinatra::Base
# ---------------------------------------------------------------
# Display the list of Domains that cannot have their urls checked
# ---------------------------------------------------------------  
  get '/skip' do
    @skips = SkipCheck.all
    erb :list_skips
  end
  
# ---------------------------------------------------------------
# Add the specified domain
# ---------------------------------------------------------------  
  post '/skip' do
    exists = false
  
    # Check if the domain specified is already part of another skip check or if another skip check contains the specified domain.
    SkipCheck.all.each do |it|
      exists = true if params[:domain].downcase.include?(it.domain) || it.domain.include?(params[:domain].downcase)
    end
  
    if !exists
      begin
        SkipCheck.create(domain: params[:domain].downcase, created_at: Time.now, group: current_user.group.id)
  
        @msg = MESSAGE_CONFIG['skip_success']
      rescue Exception => e
        status 500
        @msg = MESSAGE_CONFIG['skip_failure']
        @msg += e.message if current_user.super
  
        logger.error "#{current_user.login} - #{@msg}\n#{e.message}"
      end
    else
      status 500
      @msg = MESSAGE_CONFIG['skip_duplicate']
  
      logger.error "#{current_user.login} - #{@msg}"
    end
  
    @skips = SkipCheck.all
  
    erb :list_skips
  end  
  
# ---------------------------------------------------------------
# Delete the specified domain
# ---------------------------------------------------------------  
  delete '/skip' do
    skip = SkipCheck.find_by(domain: params[:domain].downcase)
  
    if skip
      # Check if the domain belongs to the current user's group or the current user maintains the group that the skip belongs to.
      if skip.group == current_user.group_id || !Maintainer.find_by(user_id: current_user.id, group_id: skip.group).nil? || current_user.super
        begin
          skip.destroy
  
          @msg = MESSAGE_CONFIG['skip_delete']
        rescue Exception => e
          status 500
          @msg = MESSAGE_CONFIG['skip_failure']
          @msg += e.message if current_user.super
  
          logger.error "#{current_user.login} - #{@msg}\n#{e.message}"
        end
      else
        halt(403)
      end
  
      @skips = SkipCheck.all
  
      erb :list_skips
    else
      halt(404)
    end
  end

# --------------------------------------------------------------------------------------------------------------
  before '/skip' do
    halt(401) unless logged_in?
  
    # Find the groups where the current user is a maintainer/manager
    user_groups = Group.joins(:maintainers).where(maintainers: { user_id: current_user.id })
  
    # If the user is not a maintainer/manager of any group and is not a super admin
    halt(403) if user_groups.empty? && !current_user.super
  end
  
end
class PidApp < Sinatra::Application
# --------------------------------------------------------------------------------------------------------------
# Display the group list
# --------------------------------------------------------------------------------------------------------------
  get '/group/list' do
    @groups = Group.all
    erb :list_groups
  end

# --------------------------------------------------------------------------------------------------------------
# Display the create group page
# --------------------------------------------------------------------------------------------------------------
  get '/group/new' do
    erb :new_group
  end
    
# --------------------------------------------------------------------------------------------------------------
# Find the specified group
# --------------------------------------------------------------------------------------------------------------
  get '/group/:id' do
    @group = Group.get(params[:id])
    
    redirect to('/not_found') if @group.nil?

    @associations = get_users_and_maintainer_lists(@group)
    
    erb :show_group
  end
  
# --------------------------------------------------------------------------------------------------------------
# Update the specified group with the values provided
# --------------------------------------------------------------------------------------------------------------
  put '/group/:id' do
    @group = Group.get(params[:id])
    
    redirect to('/not_found') if @group.nil?

    begin
      @group.update(:name => params[:name], :description => params[:description], :host => request.ip)
      
      @msg = MESSAGE_CONFIG['group_update_success']
    rescue Exception => e
      @msg = MESSAGE_CONFIG['group_update_failure']
      @msg += " - #{e.message}" if current_user.super   # Include the actual error is the user is sys admin
    end
    
    @associations = get_users_and_maintainer_lists(@group)
    
    erb :show_group
  end
  
# --------------------------------------------------------------------------------------------------------------
# Create a new group with the values provided
# --------------------------------------------------------------------------------------------------------------
  post '/group/:id' do
    begin
      params[:host] = request.ip
      Group.new(params).save
      
      @msg = MESSAGE_CONFIG['group_create_success']
    rescue Exception => e
      @msg = MESSAGE_CONFIG['group_create_failure']
      @msg += " - #{e.message}" if current_user.super   # Include the actual error is the user is sys admin
    end
    erb :new_group
  end
    
# --------------------------------------------------------------------------------------------------------------
# Delete the specified group (All users and maintainers must be detached before deleting)
# --------------------------------------------------------------------------------------------------------------
  delete '/group/:id' do
    @group = Group.get(params[:id])
    redirect to('/not_found') if @group.nil?
    begin
      if @group.users.empty? && @group.maintainers.empty?
        @group.destroy
      
        @msg = MESSAGE_CONFIG['group_delete_success']
      else
        @msg = MESSAGE_CONFIG['group_delete_has_children']
      end
    rescue Exception => e
      @msg = MESSAGE_CONFIG['group_delete_failure']
      @msg += " - #{e.message}" if current_user.super   # Include the actual error is the user is sys admin
    end
    erb :show_group
  end

# --------------------------------------------------------------------------------------------------------------
# Add the specified user as a maintainer of the specified group
# --------------------------------------------------------------------------------------------------------------  
  post '/group/:group/maintainer/:user' do
    group = Group.get(params[:group])
    @msg = ""
    
    redirect to('/not_found') if group.nil?

    begin
      Maintainer.new(:group => group, :user => User.get(params[:user])).save
      
      @msg = MESSAGE_CONFIG['group_add_maintainer_success']
    rescue Exception => e
      @msg = MESSAGE_CONFIG['group_add_maintainer_failure']
      @msg += " - #{e.message}" if current_user.super   # Include the actual error is the user is sys admin
    end
    
    erb @msg, :layout => false
  end

# --------------------------------------------------------------------------------------------------------------
# Remove the specified user from the list of Maintainers for the specified group
# --------------------------------------------------------------------------------------------------------------
  delete '/group/:group/maintainer/:user' do    
    group = Group.get(params[:group])
    @msg = ""
    
    redirect to('/not_found') if group.nil?

    begin
      maintainer = Maintainer.first(:group => group, :user => User.get(params[:user]))
      maintainer.destroy
      
      @msg = MESSAGE_CONFIG['group_remove_maintainer_success']
    rescue Exception => e
      @msg = MESSAGE_CONFIG['group_remove_maintainer_failure']
      @msg += " - #{e.message}" if current_user.super   # Include the actual error is the user is sys admin
    end
    
    erb @msg, :layout => false
  end
  
# --------------------------------------------------------------------------------------------------------------
# Add the specified user to the specified group
# --------------------------------------------------------------------------------------------------------------
  post '/group/:group/user/:user' do
    group = Group.get(params[:group])
    @msg = ""
    
    redirect to('/not_found') if group.nil?
    
    begin
      group.users << User.get(params[:user])
      group.save
      
      @msg = MESSAGE_CONFIG['group_add_user_success']
    rescue Exception => e
      @msg = MESSAGE_CONFIG['group_add_user_failure']
      @msg += " - #{e.message}" if current_user.super   # Include the actual error is the user is sys admin
    end
    
    erb @msg, :layout => false
  end
  
# --------------------------------------------------------------------------------------------------------------
# Remove the specified user from the specified group
# --------------------------------------------------------------------------------------------------------------
  delete '/group/:group/user/:user' do
    group = Group.get(params[:group])
    @msg = ""
    
    redirect to('/not_found') if group.nil?
    
    begin      
      group.users.delete(User.get(params[:user]))
      group.save
      
      @msg = MESSAGE_CONFIG['group_remove_user_success']
    rescue Exception => e
      @msg = MESSAGE_CONFIG['group_remove_user_failure']
      @msg += " - #{e.message}" if current_user.super   # Include the actual error is the user is sys admin
    end
    
    erb @msg, :layout => false
  end
  
# --------------------------------------------------------------------------------------------------------------
# Redirect to the login if the user isn't authenticated 
# Redirect to the unauthorized page if the user is not a super admin
# --------------------------------------------------------------------------------------------------------------
  before '/group/*' do
    if request.xhr?
      halt(401) unless logged_in?
      MESSAGE_CONFIG['user_unauthorized'] unless current_user.super
    else
      # Redirect to the login if the user isn't authenticated 
      redirect '/user/login' unless logged_in?
      
      # Return an unauthorized message if the user is not a super admin or a maintainer
      redirect '/unauthorized' unless !Maintainer.first(:user => current_user).nil? or current_user.super
    end
  end
    
  after '/group/*' do
    session[:msg] = nil
  end
    
private
  def get_users_and_maintainer_lists(group)
    ret = {:users => [], :maintainers => [], :available_users => [], :available_maintainers => []}
    
    if !group.nil?
      group.users.each{ |user| ret[:users] << user }
      Group.get(group.id).maintainers.each{ |maintainer| ret[:maintainers] << User.get(maintainer.user.id) }
      
      User.all.each{ |user| ret[:available_users] << user unless group.users.include?(user) }
      User.all.each{ |user| ret[:available_maintainers] << user unless ret[:maintainers].include?(user) }
    end
    
    ret
  end

end
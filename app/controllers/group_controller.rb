class PidApp < Sinatra::Base
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
    @group = Group.new
    erb :new_group
  end
    
# --------------------------------------------------------------------------------------------------------------
# Find the specified group
# --------------------------------------------------------------------------------------------------------------
  get '/group/:id' do
    @group = Group.find_by(id: params[:id])
    halt(404) if @group.nil?
  
    @associations = get_users_and_maintainer_lists(@group)
  
    erb :show_group
  end
  
# --------------------------------------------------------------------------------------------------------------
# Update the specified group with the values provided
# --------------------------------------------------------------------------------------------------------------
  put '/group/:id' do
    @group = Group.find_by(id: params[:id])
    halt(404) if @group.nil?
  
    begin
      @group.update(name: params[:name], description: params[:description], host: request.ip)
  
      @msg = MESSAGE_CONFIG['group_update_success']
    rescue Exception => e
      status 500
      @msg = MESSAGE_CONFIG['group_update_failure']
      @msg += " - #{e.message}" if current_user.super # Include the actual error if the user is a sys admin
  
      logger.error "#{current_user.login} - #{@msg}\n#{e.message}"
    end
  
    @associations = get_users_and_maintainer_lists(@group)
  
    erb :show_group
  end
  
# --------------------------------------------------------------------------------------------------------------
# Create a new group with the values provided
# --------------------------------------------------------------------------------------------------------------
  post '/group' do
    begin
      if Group.find_by(id: params[:id]).nil?
        @group = Group.new(
          id: params[:id],
          name: params[:name],
          description: params[:description],
          host: request.ip
        )
  
        if @group.save
          @msg = MESSAGE_CONFIG['group_create_success']
          @associations = get_users_and_maintainer_lists(@group)
        else
          status 500
          @msg = MESSAGE_CONFIG['group_create_failure']
          @msg += " - " + @group.errors.full_messages.join(', ') if current_user.super
          logger.error("#{current_user.login} - #{@msg}")
        end
      else
        status 409
        @msg = MESSAGE_CONFIG['group_create_duplicate']
      end
    rescue Exception => e
      status 500
      @msg = MESSAGE_CONFIG['group_create_failure']
      @msg += " - #{e.message}" if current_user.super
      logger.error("#{current_user.login} - #{@msg}\n#{e.message}")
    end
  
    if @associations.nil?
      erb :new_group
    else
      erb :show_group
    end
  end  
    
# --------------------------------------------------------------------------------------------------------------
# Delete the specified group (All users and maintainers must be detached before deleting)
# --------------------------------------------------------------------------------------------------------------
  delete '/group/:id' do
    @group = Group.find_by(id: params[:id])
    halt(404) if @group.nil?
  
    begin
      if @group.users.empty? && @group.maintainers.empty?
        @group.destroy
  
        @msg = MESSAGE_CONFIG['group_delete_success']
      else
        status 409
        @msg = MESSAGE_CONFIG['group_delete_has_children']
      end
    rescue Exception => e
      status 500
      @msg = MESSAGE_CONFIG['group_delete_failure']
      @msg += " - #{e.message}" if current_user.super
      logger.error "#{current_user.login} - #{@msg}\n#{e.message}"
    end
  
    @groups = Group.all
  
    if [409, 500].include?(status)
      @msg
    else
      erb :list_groups
    end
  end

# --------------------------------------------------------------------------------------------------------------
# Add the specified user as a maintainer of the specified group
# --------------------------------------------------------------------------------------------------------------  
  post '/group/:group/maintainer/:user' do
    @group = Group.find_by(id: params[:group])
    @user = User.find_by(id: params[:user])
    halt(404) if @group.nil? || @user.nil?
  
    begin
      if Maintainer.find_by(group: @group, user: @user).nil?
        Maintainer.create(group: @group, user: @user)
  
        # If the user does not have a primary group, assign them as a user of this group
        @user.update(group: @group) if @user.group.nil?
  
        @msg = MESSAGE_CONFIG['group_add_maintainer_success']
      else
        status 409
        @msg = MESSAGE_CONFIG['group_add_maintainer_duplicate']
      end
    rescue Exception => e
      status 500
      @msg = MESSAGE_CONFIG['group_add_maintainer_failure']
      @msg += " - #{e.message}" if current_user.super
      logger.error "#{current_user.login} - #{@msg}\n#{e.message}"
    end
  
    @msg
  end  

# --------------------------------------------------------------------------------------------------------------
# Remove the specified user from the list of Maintainers for the specified group
# --------------------------------------------------------------------------------------------------------------
  delete '/group/:group/maintainer/:user' do
    @group = Group.find_by(id: params[:group])
    @user = User.find_by(id: params[:user])
    halt(404) if @group.nil? || @user.nil?
  
    begin
      # Prevent the user from removing themselves as a maintainer unless they are a super user
      if current_user == @user && !current_user.super
        status 409
        @msg = MESSAGE_CONFIG['group_remove_maintainer_self']
      else
        maintainer = Maintainer.find_by(group: @group, user: @user)
  
        if maintainer
          maintainer.destroy
  
          @msg = MESSAGE_CONFIG['group_remove_maintainer_success']
        else
          status 409
          @msg = MESSAGE_CONFIG['group_remove_maintainer_missing']
        end
      end
    rescue Exception => e
      status 500
      @msg = MESSAGE_CONFIG['group_remove_maintainer_failure']
      @msg += " - #{e.message}" if current_user.super
      logger.error "#{current_user.login} - #{@msg}\n#{e.message}"
    end
  
    @msg
  end
  

# --------------------------------------------------------------------------------------------------------------
# Add the specified user to the specified group
# --------------------------------------------------------------------------------------------------------------
  post '/group/:group/user/:user' do
    @group = Group.find_by(id: params[:group])
    @user = User.find_by(id: params[:user])
    halt(404) if @group.nil? || @user.nil?
  
    begin
      if !@group.users.include?(@user)
        @group.users << @user
        @group.save
  
        @msg = MESSAGE_CONFIG['group_add_user_success']
      else
        status 409
        @msg = MESSAGE_CONFIG['group_add_user_duplicate']
      end
    rescue Exception => e
      status 500
      @msg = MESSAGE_CONFIG['group_add_user_failure']
      @msg += " - #{e.message}" if current_user.super
      logger.error "#{current_user.login} - #{@msg}\n#{e.message}"
    end
  
    @msg
  end  

# --------------------------------------------------------------------------------------------------------------
# Remove the specified user from the specified group
# --------------------------------------------------------------------------------------------------------------
  delete '/group/:group/user/:user' do
    @group = Group.find_by(id: params[:group])
    @user = User.find_by(id: params[:user])
    halt(404) if @group.nil? || @user.nil?
  
    begin
      if @group.users.include?(@user)
        @group.users.delete(@user)
        @group.save
  
        @msg = MESSAGE_CONFIG['group_remove_user_success']
      else
        status 409
        @msg = MESSAGE_CONFIG['group_remove_user_missing']
      end
    rescue Exception => e
      status 500
      @msg = MESSAGE_CONFIG['group_remove_user_failure']
      @msg += " - #{e.message}" if current_user.super
      logger.error "#{current_user.login} - #{@msg}\n#{e.message}"
    end
  
    @msg
  end
  
# --------------------------------------------------------------------------------------------------------------
# Page filters
# --------------------------------------------------------------------------------------------------------------
  # Only super admins can create/delete groups nor can they load the group list or new group pages!
  before '/group/*' do
    halt(401) unless logged_in?
  
    # If the user is not a maintainer/manager of a group
    if Maintainer.find_by(user: current_user).nil?
      # Throw an unauthorized error if the user is a super admin
      halt(403) unless current_user.super
    else
      # Throw an unauthorized error if the user is a super admin or a maintainer has access to the page
      halt(403) unless maintainer_has_access(request.request_method, request.path_info) || current_user.super
    end
  end
  

# --------------------------------------------------------------------------------------------------------------
  private
  
  def get_users_and_maintainer_lists(group)
    ret = { users: [], maintainers: [], available_users: [], available_maintainers: [] }

    if !group.nil?
      group.users.each { |user| ret[:users] << user }
      group.maintainers.each { |maintainer| ret[:maintainers] << User.find(maintainer.user_id) }

      User.find_each { |user| ret[:available_users] << user unless group.users.include?(user) }
      User.find_each { |user| ret[:available_maintainers] << user unless ret[:maintainers].include?(user) }
    end

    ret
  end

  def maintainer_has_access(method, target)
    ret = true
    # If they are trying to delete or post a group (and not add or delete a maintainer/user)
    ret = false if %w[delete post].include?(request.request_method.downcase) &&
                    !request.path_info.include?('/maintainer/') && !request.path_info.include?('/user/')

    # If they are trying to get the group list or the new group page
    ret = false if request.request_method.downcase == 'get' &&
                    %w[/group/list /group/new].include?(request.path_info.downcase)
    ret
  end

end
class PidApp < Sinatra::Application
# ---------------------------------------------------------------
# Display the login page
# ---------------------------------------------------------------
  get '/user/login' do
    
    # If the user is already logged in just redirect to the root
    if current_user.nil?
      @hide_nav = true
      
      @msg = params[:msg]
      @userid = params[:login]
      
      erb :login
    else
      redirect SECURITY_CONFIG['target_after_login']
    end
  end

# ---------------------------------------------------------------
# Process the login
# ---------------------------------------------------------------
  post '/user/login' do
    result = process_login(params['login'], params['password'])
    @msg = result[:message]
    
    if current_user.nil?
      @userid = params['login']
      @hide_nav = true      
      
      erb :login
      
    else
      redirect SECURITY_CONFIG['target_after_login']
    end
  end

# ---------------------------------------------------------------
# Process the logout
# ---------------------------------------------------------------
  get '/user/logout' do
    session.clear
    
    @hide_nav = true
    @msg = MESSAGE_CONFIG['logout']
    redirect SECURITY_CONFIG['target_after_logout']
  end

# ---------------------------------------------------------------
# Display the reset password page
# ---------------------------------------------------------------
  get '/user/reset' do
    
    if !current_user
      user = User.get(params[:n])
      
      if user && params[:c]
        @hide_nav = true
      
        # If the reset code matches the one stored on the User record and the timeout hasn't expired
        if user.reset_code == params[:c] && SECURITY_CONFIG['reset_timeout'].to_i >= ((Time.now.to_i - user.reset_timer).abs / 60)
          @n = params[:n]
          @c = params[:c]
          erb :reset_user  
        
        # Otherwise redirect to the forgot page so they can try again
        else
          msg = MESSAGE_CONFIG['user_password_reset_expired'].gsub('#{?}', SECURITY_CONFIG['reset_timeout'].to_s)

          redirect '/user/forgot', {:msg => msg}
        end
      
      else
        redirect '/user/forgot'
      end
    else
      redirect SECURITY_CONFIG['target_after_login']
    end
  end
  
# ---------------------------------------------------------------
# Process the reset password page
# ---------------------------------------------------------------
  post '/user/reset' do
    user = User.get(params[:n])
    
    if user && params[:c] && !current_user
      @hide_nav = true
      
      # If the reset code matches the one stored on the User record and the timeout hasn't expired
      if user.reset_code == params[:c] && SECURITY_CONFIG['reset_timeout'].to_i >= ((Time.now.to_i - user.reset_timer).abs / 60)

        #If the passwords match, reset the password, clear the reset key, and auto-login the user.
        if params[:password] == params[:confirm]
          user.password = params[:password]
          user.reset_timer = nil
          user.reset_code = nil
          user.save
          
          redirect '/user/login', {:login => user.login, :msg => MESSAGE_CONFIG['password_reset_success']}
        else
          @msg = MESSAGE_CONFIG['password_mismatch']
        end
        
      # Otherwise redirect to the forgot page so they can try again
      else
        msg = MESSAGE_CONFIG['user_password_reset_expired'].gsub('#{?}', SECURITY_CONFIG['reset_timeout'])

        redirect '/user/forgot', {:msg => msg}
      end
    else
      @msg = MESSAGE_CONFIG['user_password_reset_unauthorized']
      401
      redirect to('/unauthorized')
    end
    
    erb :reset_user
  end
  
# ---------------------------------------------------------------
# Display the forgot my user id / password page
# ---------------------------------------------------------------  
  get '/user/forgot' do
    
    if !current_user
      @msg = params[:msg]
    
      erb :forgot_user
    else
      redirect SECURITY_CONFIG['target_after_login']
    end
  end
  
# ---------------------------------------------------------------
# Process the forgotten user id / password form
# ---------------------------------------------------------------
  post '/user/forgot' do
    # If the user clicked the reset button reset the password and send the email
    if !params['reset'].nil? && !current_user
      
      if !params['login'].empty?
        user = User.first(:login => params['login'])
        if !user.nil?
          user.reset_password()
          user.save
          
          #TODO - Email the user a confirmation email containing their user id and new password
          #email_reset_message(user.email, user.name, user.reset_key)
          
          @msg = MESSAGE_CONFIG['user_password_reset_success']
        else
          @msg = MESSAGE_CONFIG['invalid_login']
          404
          redirect to('/not_found')
        end
      else
        @msg = MESSAGE_CONFIG['no_login']
        500
      end
    end

    @hide_nav = true
    erb :forgot_user
  end

# --------------------------------------------------------------------------------------------------------------
# Load the group's user list IF the current user is viewing their own record OR they are the group's maintainer
# --------------------------------------------------------------------------------------------------------------
  get '/user/list' do
    user = current_user
    
    if !user.nil?
      # If the current user manages the group or is an admin
      if !user.group.maintainers.first(:user => user).nil? || user.super
        @users = (user.super) ? User.all() : User.all(:group => user.group)
        @super = user.super
        
        @maintainers = {}
        Maintainer.all.each do |maintainer| 
          # If this isn't the user's main group and the user is a maintainer of the group, add its users          
          if maintainer.user == user && maintainer.group != user.group && !user.super            
            User.all(:group => maintainer.group).each{ |user| @users << user }
          end
          
          if !@maintainers[maintainer.user.id].nil?
            @maintainers[maintainer.user.id] += ", "
          end
          @maintainers[maintainer.user.id] = @maintainers[maintainer.user.id].to_s + maintainer.group.id 
        end
        
        # Sort the user list by login
        @users.sort_by{ |x,y| x.login <=> y.login unless x.nil? || y.nil? }
        
        erb :list_users
      else
        redirect "/user/#{session[:user]}"
      end
    else
      redirect '/user/login'
    end
  end
  
# --------------------------------------------------------------------------------------------------------------
# Load the registration page. If the current user is an admin or a maintainer of their group.
# --------------------------------------------------------------------------------------------------------------  
  get '/user/register' do
    user = current_user
    
    if !user.nil?
      # If the user is a maintainer of their group or an admin
      if !user.group.maintainers.first(:user => user).nil? || user.super
        @groups = Group.all if user.super
        @params = {:group => user.group.id}
        @super = user.super
        
        erb :new_user
      else
        401
        redirect to('/unauthorized')
      end
    else
      redirect '/user/login'
    end
  end

# --------------------------------------------------------------------------------------------------------------
# Process the registration page. If the current user is an admin or a maintainer of their group.
# --------------------------------------------------------------------------------------------------------------  
  post '/user/register' do
    @msg = MESSAGE_CONFIG['user_register_failure']
    user = current_user
    
    if !user.nil?
      #If the user is a maintainer of their group or is an admin
      if !user.group.maintainers.first(:user => user).nil? || user.super
      
        #If the 2 passwords match
        if params[:password] == params[:confirm]
        
          begin
            new_user = User.new(:login => params[:login], :email => params[:email], :password => params[:password],
                                :name => params[:name], :affiliation => params[:affiliation], :group => Group.get(params[:group]))
            new_user.save
        
            #group = Group.get(params[:group])
            
            # If the user was designated as a maintainer of the group and they are not already a maintainer
            #if params[:maintainer] && Maintainer.first(:group => group, :user => new_user).nil?
            #  Maintainer.new(:group => Group.get(params[:group]), :user => new_user).save
            #end
        
            @msg = MESSAGE_CONFIG['user_register_success']
            params = {} # Clear the params so the user can do another registration
        
          rescue DataMapper::SaveFailureError => e
            500
          end
                          
        else # passwords were specified but they do not match
          500
          @msg = MESSAGE_CONFIG['password_mismatch']
        end
      else  # The current user is not a group mainyainer or a super admin
        401
        redirect to('/unauthorized')
      end
    
      @super = user.super
      @groups = Group.all if user.super
      @group = user.group.id
      @params = (params) ? params : {}
    
      erb :new_user
      
    else  # The user is not logged in!
      redirect '/user/login'
    end
  end
  
# --------------------------------------------------------------------------------------------------------------
# Load the user's profile IF the current user is viewing their own record OR they are the group's maintainer OR an admin
# --------------------------------------------------------------------------------------------------------------
  get '/user/:id' do
    user = User.get(params[:id])
    curr_user = current_user
    
    if !curr_user.nil?
      if !user.nil? 
        # If the current user is trying to retrieve their own record or the current user manages the group 
        if user == curr_user || !curr_user.group.maintainers.first(:user => curr_user).nil? || curr_user.super
        
          @user = user
          @groups = (curr_user.super) ? Group.all : (!curr_user.group.maintainers.first(:user => curr_user).nil?) ? [curr_user.group] : nil          
          
          #@maintainer = true unless Maintainer.first(:group => user.group, :user => user).nil?
        
          erb :show_user
        else
          401
          redirect to('/unauthorized')
        end
      else
        404
        redirect to('/not_found')
      end
    else
      redirect '/user/login'
    end
  end
  
# --------------------------------------------------------------------------------------------------------------
# Edit the user's profile IF the current user is viewing their own record OR they are the group's maintainer OR an admin
# --------------------------------------------------------------------------------------------------------------
  put '/user/:id' do
    @msg = MESSAGE_CONFIG['user_update_failure'] 
    curr_user = current_user
    
    user = User.get(params[:id])
    group = Group.get(params[:group])
    #maintainer = Maintainer.first(:group => group, :user => user)
        
    #If the user is changing their own record or they are a maintainer of their group or is an admin
    if user == curr_user || !curr_user.group.maintainers.first(:user => curr_user).nil? || curr_user.super

      begin        
        # Assign the input values to the user
        if user.update(:login => (!params[:login].nil?) ? params[:login].downcase.strip : user.login,
                      :name => (!params[:name].nil?) ? params[:name].strip : user.login,
                      :email => (!params[:email].nil?) ? params[:email].downcase.strip : user.login,
                      :affiliation => (!params[:affiliation].nil?) ? params[:affiliation].strip : user.login,
                      :active => (params[:active] == 'on'),
                      :locked => (params[:locked] == 'on'),
                      :group => (!group.nil?) ? group : curr_user.group)
        
          # If a password change was entered, update the user's password
          user.update(:password => params[:password].strip) if !params[:password].empty? && params[:password] == params[:confirm]
          
          # Setup the Group Maintainer relationship
          #maintainer = config_group_management((params[:maintainer] == 'on'), group, user)
                          
          @msg = MESSAGE_CONFIG['user_update_success']   
        end
        
      rescue DataMapper::UpdateConflictError => uce
        500
        @msg += '<br /><br />' + user.errors.join('<br />')
      rescue Exception => e
        500
        @msg += "<br /><br />#{e.message}"
      end

    else  # The user is not a group maintainer or super admin and they're trying to access another user's account
      @msg = MESSAGE_CONFIG['user_unauthorized']
      user = curr_user.clone  # switch over to the current user to prevent the requested user's info from showing!
      401
      redirect to('/unauthorized')
    end
    
    @user = user
    @groups = (curr_user.super) ? Group.all : (!curr_user.group.maintainers.first(:user => curr_user).nil?) ? [curr_user.group] : nil
    @super = curr_user.super
    
    #@maintainer = !maintainer.nil?

    erb :show_user
  end
  
  
# --------------------------------------------------------------------------------------------------------------
# AJAX helper methods
# --------------------------------------------------------------------------------------------------------------
  get '/user/login_exists/:id' do
    status = User.first(:login => params[:id]).nil? ? 404 : 200
  end
  
  
#--------------------------------------------------------------------------------------------------------------
# Default error pages
# --------------------------------------------------------------------------------------------------------------
=begin
  not_found do
    erb :not_found
  end

  error do
    erb :error
  end
=end

# --------------------------------------------------------------------------------------------------------------
# Redirect to the login if the user isn't authenticated for all but the login/logout/forgotten password/reset password pages
# --------------------------------------------------------------------------------------------------------------
  before /^\/user\/(?!(forgot|reset|login|logout))/ do
    redirect '/user/login', {:msg => MESSAGE_CONFIG['session_expired']} unless logged_in?
  end
  
  before '/*' do
    if !current_user.nil?
      @super = true if current_user.super
    end
  end
  
# --------------------------------------------------------------------------------------------------------------
# Process the login
# --------------------------------------------------------------------------------------------------------------
private  
  def process_login(login, password)
    user = nil
    msg = MESSAGE_CONFIG['failed_login']
    
    login = "" if login.nil?
    password = "" if password.nil?
    
    if !login.empty?
      if !password.empty?
        user = User.authenticate(login, password)
        
        if !user.nil?
          session[:user] = user.id

          # reset the failed login attempts counter
          user.failed_login_attempts = 0
          user.last_login = Time.now
          user.save
      
          msg = MESSAGE_CONFIG['login'].gsub('#{?}', user.name)
          
        # The authentication failed
        else
          user = User.first(:login => login)
          
          # First check to see if the user's exists and if their account is inactive or locked
          if !user.nil?
            if user.active
              if !user.locked
                
                # if the login attempts exceed the limit defined in the config file, lock the account
                if user.failed_login_attempts.next >= SECURITY_CONFIG['max_login_attempts'].to_i
                  user.locked = true
                  # If a lock timer was specified in the config, set the timer on the user's record
                  user.locked_timer = Time.now.to_i + (SECURITY_CONFIG['release_account_lock_after'].to_i * 60) if SECURITY_CONFIG['release_account_lock_after']
                  
                  msg = MESSAGE_CONFIG['account_locked']
                  msg = msg.gsub('${?}', SECURITY_CONFIG['release_account_lock_after'].to_s) if !SECURITY_CONFIG['release_account_lock_after'].nil?

                else
                  # increment the failed login attempts counter
                  user.failed_login_attempts = user.failed_login_attempts.next
                
                  if user.failed_login_attempts >= (SECURITY_CONFIG['max_login_attempts'].to_i - 2)
                    msg = MESSAGE_CONFIG['failed_login_close_to_lockout'].gsub('#{?}', (SECURITY_CONFIG['max_login_attempts'].to_i - user.failed_login_attempts).to_s)
                  end
                end
          
                user.save
              else #locked
                msg = MESSAGE_CONFIG['account_locked']
                msg = msg.gsub('${?}', SECURITY_CONFIG['release_account_lock_after'].to_s) if !SECURITY_CONFIG['release_account_lock_after'].nil?
              end
            else #inactive
              msg = MESSAGE_CONFIG['account_inactive']
            end
          else #user id could not be found
            msg = MESSAGE_CONFIG['invalid_login']
          end
        end
        
      else #null password
        msg = MESSAGE_CONFIG['no_password']
      end
    else #null user id
      msg = MESSAGE_CONFIG['no_login']
    end
    
    {:user => user, :message => msg}
  end
  
# --------------------------------------------------------------------------------------------------------------
# Configure the group <--> user management relationship
# --------------------------------------------------------------------------------------------------------------
=begin
  def config_group_management(is_maintainer, group, user)
    
    if !group.nil? && !user.nil?
      begin
        maintainer = Maintainer.first(:group => group, :user => user)

        # remove any maintainer records for other/old groups
        Maintainer.all(:user => user).each do |maint|
          maint.destroy if maint.group != group
        end
    
        # If the user was designated as a maintainer of the group and they are not already a maintainer
        if is_maintainer && maintainer.nil?
          return Maintainer.create(:group => group, :user => user)
          
        # If the user was designated as NOT being a maintainer and they are already a maintainer
        elsif !is_maintainer && !maintainer.nil?
          maintainer.destroy
          return nil
        end
        
      rescue Exception => e
        raise e
      end
    else
      return nil
    end
  end
=end
end
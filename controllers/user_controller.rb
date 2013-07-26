#TODO - Move path to login and logout redirects to YAML file

class PidApp < Sinatra::Application
  @@config = YAML.load_file('conf/security.yml')
  @@message = YAML.load_file('conf/message.yml')

# ---------------------------------------------------------------
# Display the login page
# ---------------------------------------------------------------
  get '/user/login' do
    
    # If the user is already logged in just redirect to the root
    if session[:user].nil?
      @hide_nav = true
      
      @msg = params[:msg]
      @userid = params[:login]
      
      erb :login
    else
      redirect '/link'
    end
  end

# ---------------------------------------------------------------
# Process the login
# ---------------------------------------------------------------
  post '/user/login' do
    result = process_login(params['login'], params['password'])
    @msg = result[:message]
    
    if session[:user].nil?
      @userid = params['login']
      @hide_nav = true      
      
      erb :login
      
    else
      redirect '/link'
    end
  end

# ---------------------------------------------------------------
# Process the logout
# ---------------------------------------------------------------
  get '/user/logout' do
    session.clear
    
    @hide_nav = true
    @msg = @@message['logout']
    redirect '/user/login'
  end

# ---------------------------------------------------------------
# Display the reset password page
# ---------------------------------------------------------------
  get '/user/reset' do
    user = User.get(params[:n])
      
    if user && params[:c]
      @hide_nav = true
      
      # If the reset code matches the one stored on the User record and the timeout hasn't expired
      if user.reset_code == params[:c] && @@config['reset_timeout'].to_i >= ((Time.now.to_i - user.reset_timer).abs / 60)
        @n = params[:n]
        @c = params[:c]
        erb :reset_user  
        
      # Otherwise redirect to the forgot page so they can try again
      else
        msg = @@message['user_password_reset_expired'].gsub('#{?}', @@config['reset_timeout'].to_s)

        redirect '/user/forgot', {:msg => msg}
      end
      
    else
      redirect '/user/forgot'
    end
  end
  
# ---------------------------------------------------------------
# Process the reset password page
# ---------------------------------------------------------------
  post '/user/reset' do
    user = User.get(params[:n])
    
    if user && params[:c]
      @hide_nav = true
      
      # If the reset code matches the one stored on the User record and the timeout hasn't expired
      if user.reset_code == params[:c] && @@config['reset_timeout'].to_i >= ((Time.now.to_i - user.reset_timer).abs / 60)

        #If the passwords match, reset the password, clear the reset key, and auto-login the user.
        if params[:password] == params[:confirm]
          user.password = params[:password]
          user.reset_timer = nil
          user.reset_code = nil
          user.save
          
          redirect '/user/login', {:login => user.login, :msg => @@message['password_reset_success']}
        else
          @msg = @@message['password_mismatch']
        end
        
      # Otherwise redirect to the forgot page so they can try again
      else
        msg = @@message['user_password_reset_expired'].gsub('#{?}', @@config['reset_timeout'])

        redirect '/user/forgot', {:msg => msg}
      end
    else
      @msg = @@message['user_password_reset_unauthorized']
      401
      erb :unauthorized
    end
    
    erb :reset_user
  end
  
# ---------------------------------------------------------------
# Display the forgot my user id / password page
# ---------------------------------------------------------------  
  get '/user/forgot' do
    @hide_nav = true
    @msg = params[:msg]
    
    erb :forgot_user
  end
  
# ---------------------------------------------------------------
# Process the forgotten user id / password form
# ---------------------------------------------------------------
  post '/user/forgot' do
    # If the user clicked the reset button reset the password and send the email
    if !params['reset'].nil?
      
      if !params['login'].empty?
        user = User.first(:login => params['login'])
        if !user.nil?
          user.reset_password()
          user.save
          
          #TODO - Email the user a confirmation email containing their user id and new password
          #email_reset_message(user.email, user.name, user.reset_key)
          
          @msg = @@message['user_password_reset_success']
        else
          @msg = @@message['invalid_login']
          404
          erb :not_found
        end
      else
        @msg = @@message['no_login']
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
    user = User.get(session[:user])
    
    if !user.nil?
      # If the current user manages the group or is an admin
      if !user.group.maintainers.first(:user => user).nil? || user.super
        @users = (user.super) ? User.all(:order => [:login.asc]) : User.all(:group => user.group, :order => [:login.asc])
        @super = user.super
        
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
    user = User.get(session[:user])
    
    if !user.nil?
      # If the user is a maintainer of their group or an admin
      if !user.group.maintainers.first(:user => user).nil? || user.super
        @groups = Group.all if user.super
        @params = {:group => user.group.id}
        @super = user.super
        
        erb :new_user
      else
        401
        erb :unauthorized
      end
    else
      redirect '/user/login'
    end
  end

# --------------------------------------------------------------------------------------------------------------
# Process the registration page. If the current user is an admin or a maintainer of their group.
# --------------------------------------------------------------------------------------------------------------  
  post '/user/register' do
    @msg = @@message['user_register_failure']
    current_user = User.get(session[:user])
    
    if !current_user.nil?
      #If the user is a maintainer of their group or is an admin
      if !current_user.group.maintainers.first(:user => current_user).nil? || current_user.super
      
        #If the 2 passwords match
        if params[:password] == params[:confirm]
        
          begin
            new_user = User.new(:login => params[:login], :email => params[:email], :password => params[:password],
                                :name => params[:name], :affiliation => params[:affiliation], :group => Group.get(params[:group]))
            new_user.save
        
            group = Group.get(params[:group])
            
            # If the user was designated as a maintainer of the group and they are not already a maintainer
            if params[:maintainer] && Maintainer.first(:group => group, :user => new_user).nil?
              Maintainer.new(:group => Group.get(params[:group]), :user => new_user).save
            end
        
            @msg = @@message['user_register_success']
            params = {} # Clear the params so the user can do another registration
        
          rescue DataMapper::SaveFailureError => e
            500
          end
                          
        else # passwords were specified but they do not match
          500
          @msg = @@message['password_mismatch']
        end
      else  # The current user is not a group mainyainer or a super admin
        401
        erb :unauthorized
      end
    
      @super = current_user.super
      @groups = Group.all if current_user.super
      @group = current_user.group.id
      @params = params
    
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
    current_user = User.get(session[:user])
    
    if !current_user.nil?
      if !user.nil? 
        # If the current user is trying to retrieve their own record or the current user manages the group 
        if user == current_user || !current_user.group.maintainers.first(:user => current_user).nil? || current_user.super
        
          @user = user
          @groups = (current_user.super) ? Group.all : (!current_user.group.maintainers.first(:user => current_user).nil?) ? [current_user.group] : nil
          
          @maintainer = true unless Maintainer.first(:group => user.group, :user => user).nil?
        
          erb :show_user
        else
          401
          erb :unauthorized
        end
      else
        404
        erb :not_found
      end
    else
      redirect '/user/login'
    end
  end
  
# --------------------------------------------------------------------------------------------------------------
# Edit the user's profile IF the current user is viewing their own record OR they are the group's maintainer OR an admin
# --------------------------------------------------------------------------------------------------------------
  put '/user/:id' do
    @msg = @@message['user_update_failure'] 
    current_user = User.get(session[:user])
    
    user = User.get(params[:id])
    group = Group.get(params[:group])
    maintainer = Maintainer.first(:group => group, :user => user)
        
    #If the user is changing their own record or they are a maintainer of their group or is an admin
    if user == current_user || !current_user.group.maintainers.first(:user => current_user).nil? || current_user.super

      begin        
        # Assign the input values to the user
        if user.update(:login => (!params[:login].nil?) ? params[:login].downcase.strip : user.login,
                      :name => (!params[:name].nil?) ? params[:name].strip : user.login,
                      :email => (!params[:email].nil?) ? params[:email].downcase.strip : user.login,
                      :affiliation => (!params[:affiliation].nil?) ? params[:affiliation].strip : user.login,
                      :active => (params[:active] == 'on'),
                      :locked => (params[:locked] == 'on'),
                      :group => (!group.nil?) ? group : current_user.group)
        
          # If a password change was entered, update the user's password
          user.update(:password => params[:password].strip) if !params[:password].empty? && params[:password] == params[:confirm]
          
          # Setup the Group Maintainer relationship
          maintainer = config_group_management((params[:maintainer] == 'on'), group, user)
                          
          @msg = @@message['user_update_success']   
        end
        
      rescue DataMapper::UpdateConflictError => uce
        500
        @msg += '<br /><br />' + user.errors.join('<br />')
      rescue Exception => e
        500
        @msg += "<br /><br />#{e.message}"
      end

    else  # The user is not a group maintainer or super admin and they're trying to access another user's account
      @msg = @@message['user_unauthorized']
      user = current_user.clone  # switch over to the current user to prevent the requested user's info from showing!
      401
      erb :unauthorized
    end
    
    @user = user
    @groups = (current_user.super) ? Group.all : (!current_user.group.maintainers.first(:user => current_user).nil?) ? [current_user.group] : nil
    @super = current_user.super
    
    @maintainer = !maintainer.nil?
    
    
    # Populate the groups list to display in select box if the current user is a super admin
    @groups = Group.all if current_user.super

    erb :show_user
  end
  
  
# --------------------------------------------------------------------------------------------------------------
# Redirect to the login if the user isn't authenticated for all but the login/logout/forgotten password/reset password pages
# --------------------------------------------------------------------------------------------------------------
  before /^(?!\/user\/(forgot|reset|login|logout))/ do
    redirect '/user/login', {:msg => @@message['session_expired']} if session[:user].nil?
  end
  
  
# --------------------------------------------------------------------------------------------------------------
# Process the login
# --------------------------------------------------------------------------------------------------------------
  def process_login(login, password)
    user = nil
    msg = @@message['failed_login']
    
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
      
          msg = @@message['login'].gsub('#{?}', user.name)
          
        # The authentication failed
        else
          user = User.first(:login => login)
          
          # First check to see if the user's exists and if their account is inactive or locked
          if !user.nil?
            if user.active
              if !user.locked
                
                # if the login attempts exceed the limit defined in the config file, lock the account
                if user.failed_login_attempts.next >= @@config['max_login_attempts'].to_i
                  user.locked = true
                  # If a lock timer was specified in the config, set the timer on the user's record
                  user.locked_timer = Time.now.to_i + (@@config['release_account_lock_after'].to_i * 60) if @@config['release_account_lock_after']
                  
                  msg = @@message['account_locked']
                  msg = msg.gsub('${?}', @@config['release_account_lock_after'].to_s) if !@@config['release_account_lock_after'].nil?

                else
                  # increment the failed login attempts counter
                  user.failed_login_attempts = user.failed_login_attempts.next
                
                  if user.failed_login_attempts >= (@@config['max_login_attempts'].to_i - 2)
                    msg = @@message['failed_login_close_to_lockout'].gsub('#{?}', (@@config['max_login_attempts'].to_i - user.failed_login_attempts).to_s)
                  end
                end
          
                user.save
              else #locked
                msg = @@message['account_locked']
                msg = msg.gsub('${?}', @@config['release_account_lock_after'].to_s) if !@@config['release_account_lock_after'].nil?
              end
            else #inactive
              msg = @@message['account_inactive']
            end
          else #user id could not be found
            msg = @@message['invalid_login']
          end
        end
        
      else #null password
        msg = @@message['no_password']
      end
    else #null user id
      msg = @@message['no_login']
    end
    
    {:user => user, :message => msg}
  end
  
# --------------------------------------------------------------------------------------------------------------
# Configure the group <--> user management relationship
# --------------------------------------------------------------------------------------------------------------
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
end
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
        
    if !session[:user].nil?
      redirect '/link'
      return nil
      
    else
      @userid = params['login']
      @hide_nav = true      
      #erb :login
    end
  end

# ---------------------------------------------------------------
# Process the logout
# ---------------------------------------------------------------
  get '/user/logout' do
    session[:user] = nil
    @hide_nav = true
    @msg = @@message['logout']
    redirect '/user/login'
  end


  get '/user/reset' do
    #TODO - reset temporary passwords (passwords created by group managers or admins, or forgotten reset)
    @hide_nav = true
    erb :reset_user
  end
  
  get '/user/forgot' do
    @hide_nav = true
    erb :forgot_user
  end
  
# ---------------------------------------------------------------
# Process the forgotten user id / password form
# ---------------------------------------------------------------
  post '/user/forgot' do
    # If the user clicked the reset button reset the password and send the email
    if !params['reset'].nil?
      
      if !params['email'].empty?
        user = User.first(:email => params['email'])
        if !user.nil?
          user.reset_password
          
          #TODO - Email the user a confirmation email containing their user id and new password
          #email_reset_message(user.email, user.name, user.reset_key)
          
          @msg = @@message['password_reset']
        else
          @msg = @@message['invalid_email']
        end
      else
        @msg = @@message['no_email']
      end
    end

    @hide_nav = true
    erb :forgot_user
  end

# --------------------------------------------------------------------------------------------------------------
# Load the group's user list IF the current user is viewing their own record OR they are the group's maintainer
# --------------------------------------------------------------------------------------------------------------
  get '/user/list' do
    #TODO - Allow admins of the system to get the full user list regardless of group

    group = Group.get(session[:user].group.id)
    
    # If the current user manages the group 
    if !group.maintainers.first(:user => session[:user]).nil?
      @users = group.users
      erb :show_user
    else
      401
    end
  end
  
  
  get '/user/register' do
    @hide_nav = true
    erb :new_user
  end

  post '/user/register' do
    #TODO - Only group managers can add users to their group. Only admins can create initial group managers
    @user = User.new(params)
    begin
      @user.save
      redirect "/user/#{@user.login}"
    rescue DataMapper::SaveFailureError => e
      @hide_nav = true
      @msg = "#{e.message}"
      erb :new_user
    end
  end
  
# --------------------------------------------------------------------------------------------------------------
# Load the user's profile IF the current user is viewing their own record OR they are the group's maintainer
# --------------------------------------------------------------------------------------------------------------
  get '/user/:name' do
    #TODO - Allow admins of the system to get any user profile regardless of group
    @user = User.first(:login => params[:name])
    
    if @user 
      group = Group.get(@user.group.id)
      
      # If the current user is trying to retrieve their own record or the current user manages the group 
      if @user == session[:user] || !group.maintainers.first(:user => session[:user]).nil?
        erb :show_user
      else
        401
      end
    else
      404
    end
  end
  
  
  put '/user/:name' do
    #TODO - update user (only if its the current user's account or an admin or a group manager)
  end
  
  delete '/user/:name' do
    #TODO - deactivate the user account (only if the current user is admin or a group manager!)
  end
  
  

  before /^(?!\/user\/(forgot|reset|register|login|logout))/ do
    #TODO - restrict access to '/user/:name' to the current user, or user's within a manager's group (admin can see all)
    status = 302
    redirect '/user/login' if session[:user].nil?
  end
  
  
  
  def process_login(login, password)
    user = nil
    msg = @@message['failed_login']
    
    login = "" if login.nil?
    password = "" if password.nil?
    
    if !login.empty?
      user = User.first(:login => login)
      
      if !password.empty?
        if session[:user] = User.authenticate(login, password)
          # reset the failed login attempts counter
          user.failed_login_attempts = 0
          user.save
      
          msg = @@message['login'].gsub('#{?}', user.name)
          
        # The authentication failed
        else
          # First check to see if the user's exists and if their account is inactive or locked
          if !user.nil?
            if user.active
              if !user.locked
                
                # if the login attempts exceed the limit defined in the config file, lock the account
                if user.failed_login_attempts.next >= @@config['max_login_attempts'].to_i
                  user.locked = true
                  msg = @@message['account_locked']
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
end
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
    session[:user] = nil
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
        erb :reset_user  
        
      # Otherwise redirect to the forgot page so they can try again
      else
        msg = "Your password reset request has expired. For security reasons you have only #{@@config['reset_timeout']} minutes between " +
                  "the time you request a reset and you follow the link to the reset form in the confirmation email."

        redirect '/user/forgot', {:msg => msg}
      end
      
    else
      401
    end
  end
  
# ---------------------------------------------------------------
# Display the forgot my user id / password page
# ---------------------------------------------------------------  
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
          user.reset_password()
          
          #TODO - Email the user a confirmation email containing their user id and new password
          #email_reset_message(user.email, user.name, user.reset_key)
          
          @msg = @@message['password_reset']
        else
          @msg = @@message['invalid_email']
          404
        end
      else
        @msg = @@message['no_email']
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
    # If the current user manages the group or an admin
    if !session[:user].group.maintainers.first(:user => session[:user]).nil? || session[:user].super
      @users = (session[:user].super) ? User.all : session[:user].group.users
      
      erb :list_users
    else
      redirect "/user/#{session[:user].id}"
    end
  end
  
# --------------------------------------------------------------------------------------------------------------
# Load the registration page. If the current user is and admin or a maintainer of their group.
# --------------------------------------------------------------------------------------------------------------  
  get '/user/register' do
    # If the user is a maintainer of their group or an admin
    if !session[:user].group.maintainers.first(:user => session[:user]).nil? || session[:user].super
      @groups = Group.all if session[:user].super
      @group = session[:user].group.name if !session[:user].super
        
      erb :new_user
    else
      401
    end
  end

# --------------------------------------------------------------------------------------------------------------
# Process the registration page. If the current user is and admin or a maintainer of their group.
# --------------------------------------------------------------------------------------------------------------  
  post '/user/register' do
    #If the user is a maintainer of their group or is an admin
    if !session[:user].group.maintainers.first(:user => session[:user]).nil? || session[:user].super
      
      #If the 2 passwords match
      if params[:password] == params[:confirm]
        
        begin
          @user = User.new(:login => params[:login], :email => params[:email], :password => params[:password],
                            :name => params[:name], :affiliation => params[:affiliation], :group => Group.get(params[:group])).save
        
          # If the user was designated as a maintainer of the group
          if params[:maintainer]
            Maintainer.new(:group => Group.get(params[:group]), :user => @user).save
          end
        
        rescue DataMapper::SaveFailureError => e
          500
          @msg = 'Unable to register the new user!'
        end
                          
      else
        500
        @msg = 'The two passwords did not match!'
      end
    else
      401
    end
    
    erb :new_user
  end
  
# --------------------------------------------------------------------------------------------------------------
# Load the user's profile IF the current user is viewing their own record OR they are the group's maintainer OR an admin
# --------------------------------------------------------------------------------------------------------------
  get '/user/:id' do
    @user = User.get(params[:id])
    
    if @user 
      # If the current user is trying to retrieve their own record or the current user manages the group 
      if @user == session[:user] || !session[:user].group.maintainers.first(:user => session[:user]).nil? || session[:user].super
        
        @groups = Group.all if session[:user].super
        @group = @user.group.name if @user == session[:user]
        @maintainer = true unless Maintainer.first(:group => @user.group, :user => @user).nil?
        
        erb :show_user
      else
        401
      end
    else
      404
    end
  end
  
# --------------------------------------------------------------------------------------------------------------
# Edit the user's profile IF the current user is viewing their own record OR they are the group's maintainer OR an admin
# --------------------------------------------------------------------------------------------------------------
  put '/user/:id' do
    @user = User.get(params[:id])
    current_user = session[:user]
        
    #If the user is changing their own record or they are a maintainer of their group or is an admin
    if @user == current_user || !current_user.group.maintainers.first(:user => current_user).nil? || current_user.super

      #If the 2 passwords match
      if params[:password] == params[:confirm]

        begin
          @user.email = params[:email] unless params[:email].nil?
          @user.password = params[:password] unless params[:password].nil?
          @user.name = params[:name] unless params[:name].nil?
          @user.affiliation = params[:affiliation] unless params[:affiliation].nil?
          @user.active = params[:active] unless params[:active].nil?
          @user.group = Group.get(params[:group]) unless params[:group].nil?
            
          @user.save
            
          # If the user was designated as a maintainer of the group
          if params[:maintainer]
            Maintainer.new(:group => Group.get(params[:group]), :user => @user).save
          end
        
        rescue DataMapper::SaveFailureError => e
          500
          @msg = 'Unable to save your changes!'
        end

      else
        @user = current_user.clone
        500
        @msg = 'The two passwords did not match!'
      end

    else
      @user = current_user.clone
      401
    end
    
    @groups = Group.all if current_user.super
    @group = @user.group.name if @user == current_user
    @maintainer = true unless Maintainer.first(:group => @user.group, :user => @user).nil?
    
    erb :show_user
  end
  
  
# --------------------------------------------------------------------------------------------------------------
# Redirect to the login if the user isn't authenticated for all but the login/logout/forgotten password/reset password pages
# --------------------------------------------------------------------------------------------------------------
  before /^(?!\/user\/(forgot|reset|login|logout))/ do
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
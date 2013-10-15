class PidApp < Sinatra::Application
# ---------------------------------------------------------------
# Display the administration page
# ---------------------------------------------------------------
  get '/user/admin' do
    @super = current_user.super
    
    halt(403) unless @super or !Maintainer.first(:user => current_user).nil?
    
    erb :show_admin
  end
    
# ---------------------------------------------------------------
# Display the login page
# ---------------------------------------------------------------
  get '/user/login' do
    # If the user is already logged in just redirect to the root
    if current_user.nil?
      @hide_nav = true
      
      @msg = session[:msg]
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
    result = process_login(params['login'], params['password'], request.ip)
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
    
    if current_user.nil?
      user = User.get(params[:n])
      
      if user && params[:c]
        @hide_nav = true
      
        # If the reset code matches the one stored on the User record and the timeout hasn't expired
        if user.reset_code == params[:c] && SECURITY_CONFIG['password_reset_timeout'].to_i >= ((Time.now.to_i - user.reset_timer).abs / 60)
          @n = params[:n]
          @c = params[:c]
          erb :reset_user  
        
        # Otherwise redirect to the forgot page so they can try again
        else
          session[:msg] = MESSAGE_CONFIG['user_password_reset_expired'].gsub('#{?}', SECURITY_CONFIG['password_reset_timeout'].to_s)

          redirect '/user/forgot'
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
    usr = User.get(params[:n])
    
    if usr && params[:c] && !current_user
      @hide_nav = true
      
      # If the reset code matches the one stored on the User record and the timeout hasn't expired
      if usr.reset_code == params[:c] && SECURITY_CONFIG['password_reset_timeout'].to_i >= ((Time.now.to_i - usr.reset_timer).abs / 60)

        #If the passwords match, reset the password, clear the reset key, and auto-login the user.
        if params[:password] == params[:confirm]
          usr.password = params[:password]
          usr.reset_timer = nil
          usr.reset_code = nil
          usr.reset_attempts = 0
          usr.host = request.ip
          usr.save
          
          session[:msg] = MESSAGE_CONFIG['user_password_reset_success']
          
          redirect '/user/login'
        else
          status 409
          @msg = MESSAGE_CONFIG['password_mismatch']
        end
        
      # Otherwise redirect to the forgot page so they can try again
      else
        session[:msg] = MESSAGE_CONFIG['user_password_reset_expired'].gsub('#{?}', SECURITY_CONFIG['password_reset_timeout'])

        redirect '/user/forgot'
      end
    else
      halt(403)
    end
    
    erb :reset_user
  end
  
# ---------------------------------------------------------------
# Display the forgot my user id / password page
# ---------------------------------------------------------------  
  get '/user/forgot' do
    if current_user.nil?
      @msg = session[:msg]
      @hide_nav = true

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
        usr = User.first(:login => params['login'])
        if !usr.nil?
          # If the account is locked do not allow the reset request
          if usr.locked
            @msg = MESSAGE_CONFIG['account_locked']
            @msg = @msg.gsub('${?}', SECURITY_CONFIG['release_account_lock_after'].to_s) if !SECURITY_CONFIG['release_account_lock_after'].nil?
          else
            if usr.reset_attempts < SECURITY_CONFIG['max_login_attempts'].to_i
              usr.reset_password()
              usr.host = request.ip
              usr.save
          
              # Create the reset URL
              url = "#{hostname}user/reset?n=#{usr.id}&c=#{usr.reset_code}"
          
              # Get the notification email settings
              cc = SECURITY_CONFIG['password_reset_email_cc']
              bc = SECURITY_CONFIG['password_reset_email_bcc']
              subject = SECURITY_CONFIG['password_reset_email_subject']
              body = SECURITY_CONFIG['password_reset_email_body'].gsub('{?name?}', usr.name).gsub('{?url?}', url).gsub('{?affiliation?}', 
                    usr.affiliation.to_s).gsub('{?group?}', usr.group.id).gsub('{?timeframe?}', SECURITY_CONFIG['password_reset_timeout'].to_s)
          
              send_email(usr.email, subject, body)
          
              @msg = MESSAGE_CONFIG['user_password_reset_email']
            
            # Too many reset password attempts have been made, so lock the account
            else
              usr.locked = true
              usr.reset_attempts = 0
              usr.host = request.ip
              usr.save
            
              # Get the administrator notification email settings
              to = SECURITY_CONFIG['account_lock_email_to']
              cc = SECURITY_CONFIG['account_lock_email_cc']
              subject = SECURITY_CONFIG['account_lock_email_subject']
              body = SECURITY_CONFIG['account_lock_email_body'].gsub('{?login?}', usr.login).gsub('{?name?}', usr.name).gsub('{?email?}', 
                                      usr.email).gsub('{?ip?}', request.ip)
            
              send_email(to, subject, body)
            
              @msg = MESSAGE_CONFIG['user_password_forgot_max_attempts']
            end
          end
        else
          halt(404)
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
    
    # If the current user manages the group or is an admin
    if !current_user.group.maintainers.first(:user => current_user).nil? || current_user.super
      @users = (current_user.super) ? User.all() : User.all(:group => current_user.group)
      @super = current_user.super
        
      @maintainers = {}
      Maintainer.all.each do |maintainer| 
        # If this isn't the user's main group and the user is a maintainer of the group, add its users          
        if maintainer.user == user && maintainer.group != current_user.group && !current_user.super            
          User.all(:group => maintainer.group).each{ |user| @users << user }
        end
          
        if !@maintainers[maintainer.user.id].nil?
          @maintainers[maintainer.user.id] += ", "
        end
        @maintainers[maintainer.user.id] = @maintainers[maintainer.user.id].to_s + maintainer.group.id 
      end
        
      # Sort the user list by login
      @users.sort!{ |x,y| x.login <=> y.login unless x.nil? || y.nil? }
        
      erb :list_users
    else
      halt(403)
    end
  end
  
# --------------------------------------------------------------------------------------------------------------
# Load the registration page. If the current user is an admin or a maintainer of their group.
# --------------------------------------------------------------------------------------------------------------  
  get '/user/register' do
    
    # If the user is a maintainer of their group or an admin
    if !current_user.group.maintainers.first(:user => current_user).nil? || current_user.super
      @groups = (current_user.super) ? Group.all : []
      
      if !current_user.super
        Maintainer.all(:user => current_user).each do |maint|
         @groups << maint.group 
        end
      end
      
      @groups = nil if @groups.count <= 1
      
      @params = {:group => current_user.group.id}
      @super = current_user.super
      @user = User.new
      
      erb :new_user
    else
      halt(403)
    end
  end

# --------------------------------------------------------------------------------------------------------------
# Process the registration page. If the current user is an admin or a maintainer of their group.
# --------------------------------------------------------------------------------------------------------------  
  post '/user/register' do
    #If the user is a maintainer of their group or is an admin
    if !current_user.group.maintainers.first(:user => current_user).nil? || current_user.super
      
      #If the 2 passwords match
      if params[:password] == params[:confirm]
        
        begin
          group = params[:group].nil? ? current_user.group : Group.first(:id => params[:group])
          
          # If the group isn't the current user's, make sure they're a maintainer for the specified group
          if group != current_user.group and !current_user.super
            group = nil if Maintainer.first(:group => group, :user => current_user).nil?
          end
          
          if !group.nil?
            new_user = User.new(:login => params[:login], 
                                :email => params[:email], 
                                :password => params[:password], 
                                :host => request.ip,
                                :name => params[:name], 
                                :affiliation => params[:affiliation], 
                                :active => true,
                                :group => group,
                                :read_only => (current_user.super) ? (params[:read_only] == 'on') : false )

            new_user.save
        
            @user = new_user
          
            @msg = MESSAGE_CONFIG['user_register_success']
            params = {} # Clear the params so the user can do another registration
        
          else
            status 409
            @msg = MESSAGE_CONFIG['user_register_invalid_group']
          end
          
        rescue DataMapper::SaveFailureError => e
          status 500
          @msg = MESSAGE_CONFIG['user_register_failure']
          
          logger.error "#{current_user.login} - #{@msg}\n#{e.message}"
        end
                          
      else # passwords were specified but they do not match
        @msg = MESSAGE_CONFIG['password_mismatch']
      end
    else  # The current user is not a group mainyainer or a super admin
      halt(403)
    end
    
    @groups = (current_user.super) ? Group.all : []
    
    if !current_user.super
      Maintainer.all(:user => current_user).each do |maint|
       @groups << maint.group 
      end
    end
    
    @groups = nil if @groups.count <= 1
    
    @params = {:group => current_user.group.id}
    @super = current_user.super
    @params = (params) ? params : {}
    
    erb :new_user  
  end
  
# --------------------------------------------------------------------------------------------------------------
# Load the user's profile IF the current user is viewing their own record OR they are the group's maintainer OR an admin
# --------------------------------------------------------------------------------------------------------------
  get '/user/:id' do
    @user = User.first(:id => params[:id])

    halt(404) if @user.nil?
    
    if !current_user.nil?
      # If the current user is trying to retrieve their own record or the current user manages the group 
      if @user == current_user || !current_user.group.maintainers.first(:user => current_user).nil? || current_user.super
        
        #@groups = (current_user.super) ? Group.all : (!current_user.group.maintainers.first(:user => current_user).nil?) ? [current_user.group] : nil          
        @groups = (current_user.super) ? Group.all : []
      
        if !current_user.super
          Maintainer.all(:user => current_user).each do |maint|
           @groups << maint.group 
          end
        end
        
        @groups = nil if @groups.count <= 1
          
        erb :show_user
      else
        halt(403)
      end
    else
      redirect '/user/login'
    end
  end
  
# --------------------------------------------------------------------------------------------------------------
# Edit the user's profile IF the current user is viewing their own record OR they are the group's maintainer OR an admin
# --------------------------------------------------------------------------------------------------------------
  put '/user/:id' do
    @user = User.first(:id => params[:id])
    halt(404) if  @user.nil?
    
    @msg = MESSAGE_CONFIG['user_update_failure'] 
    
    #If the user is changing their own record or they are a maintainer of their group or is an admin
    if @user == current_user || !current_user.group.maintainers.first(:user => current_user).nil? || current_user.super

      begin        
        # Assign the input values to the user
        if @user.update(:login => (!params[:login].nil?) ? params[:login].downcase.strip : @user.login,
                      :name => (!params[:name].nil?) ? params[:name].strip : @user.name,
                      :email => (!params[:email].nil?) ? params[:email].downcase.strip : @user.email,
                      :affiliation => (!params[:affiliation].nil?) ? params[:affiliation].strip : @user.affiliation,
                      :active => (params[:active] == 'on'),
                      :locked => (params[:locked] == 'on'),
                      :group => (!params[:group].nil?) ? Group.first(:id => params[:group]) : current_user.group,
                      :host => request.ip,
                      :read_only => (current_user.super) ? (params[:read_only] == 'on') : @user.read_only)
        
          # If a password change was entered, update the user's password
          @user.update(:password => params[:password].strip) if params[:password].strip != '' && params[:password] == params[:confirm]
          
          @msg = MESSAGE_CONFIG['user_update_success']   
        end
        
      rescue Exception => e
        500
        @msg = MESSAGE_CONFIG['user_update_failure']
        @msg += "<br /><br />#{e.message}" if current_user.super
        @msg += '<br /><br />' + @user.errors.inspect if current_user.super

        logger.error "#{current_user.login} - #{@msg}\n#{e.message}"
      end

    else  # The user is not a group maintainer or super admin and they're trying to access another user's account
      halt(403)
    end
    
    @groups = (current_user.super) ? Group.all : (!Maintainer.first(:user => current_user, :group => current_user.group).nil?) ? [current_user.group] : nil
    
    @super = current_user.super

    erb :show_user
  end
  
  get '/' do
    erb :login
  end
  
# --------------------------------------------------------------------------------------------------------------
# AJAX helper methods
# --------------------------------------------------------------------------------------------------------------
  get '/user/login_exists/:id' do
    status = User.first(:login => params[:id]).nil? ? 404 : 200
  end

# --------------------------------------------------------------------------------------------------------------
# Page filters
# --------------------------------------------------------------------------------------------------------------
  # Only super admins can create/delete groups nor can they load the group list or new group pages!
  before /^\/user\/(?!(forgot|reset|login|logout))/ do
    halt(401) unless logged_in?
    
    # If the user has a readonly account prevent them from running the post/put/delete commands!
    halt(403) if ['post', 'delete'].include?(request.request_method) && current_user.read_only
  end

# --------------------------------------------------------------------------------------------------------------
  before '/*' do
    if !current_user.nil?
      @super = true if current_user.super
      @read_only = current_user.read_only
    else
      @super = false
      @read_only = false
    end
  end
  
# --------------------------------------------------------------------------------------------------------------
# The following routes handle ALL errors for the entire application!!!
# --------------------------------------------------------------------------------------------------------------
  after '*' do
    session[:msg] = nil
  end

# --------------------------------------------------------------------------------------------------------------
  not_found do
    logger.warn "#{current_user.login unless current_user.nil?} got a 404 on #{request.path}"
    
    @msg = MESSAGE_CONFIG['user_not_found']
    @msg if request.xhr?
    erb :not_found unless request.xhr?
  end

# --------------------------------------------------------------------------------------------------------------
  error 401 do
    @msg = MESSAGE_CONFIG['session_expired']
    @msg if request.xhr?
    erb :login unless request.xhr?
  end

# --------------------------------------------------------------------------------------------------------------
  error 403 do
    logger.warn "#{current_user.login unless current_user.nil?} was unauthorized on #{request.path}"
    
    @msg = MESSAGE_CONFIG['user_unauthorized']
    @msg if request.xhr?
    erb :unauthorized unless request.xhr?
  end
  
# --------------------------------------------------------------------------------------------------------------
# Process the login
# --------------------------------------------------------------------------------------------------------------
private  
  def process_login(login, password, ip)
    user = nil
    msg = MESSAGE_CONFIG['failed_login']
    
    login = "" if login.nil?
    password = "" if password.nil?
    
    if !login.empty?
      if !password.empty?
        usr = User.authenticate(login, password)
        
        if !usr.nil?
          session[:user] = usr.id

          # reset the failed login attempts counter
          usr.failed_login_attempts = 0
          usr.last_login = Time.now
          usr.save
      
          msg = MESSAGE_CONFIG['login'].gsub('#{?}', usr.name)
          
        # The authentication failed
        else
          usr = User.first(:login => login)
          
          # First check to see if the user's exists and if their account is inactive or locked
          if !usr.nil?
            if usr.active
              if !usr.locked
                
                # if the login attempts exceed the limit defined in the config file, lock the account
                if usr.failed_login_attempts.next >= SECURITY_CONFIG['max_login_attempts'].to_i
                  usr.locked = true
                  # If a lock timer was specified in the config, set the timer on the user's record
                  usr.locked_timer = Time.now.to_i + (SECURITY_CONFIG['release_account_lock_after'].to_i * 60) if SECURITY_CONFIG['release_account_lock_after']
                  usr.host = ip
                  
                  # Get the administrator notification email settings
                  to = SECURITY_CONFIG['account_lock_email_to']
                  cc = SECURITY_CONFIG['account_lock_email_cc']
                  subject = SECURITY_CONFIG['account_lock_email_subject']
                  body = SECURITY_CONFIG['account_lock_email_body'].gsub('{?login?}', usr.login).gsub('{?name?}', usr.name).gsub('{?email?}', 
                        usr.email).gsub('{?ip?}', ip)
                  
                  send_email(to, subject, body)
                  
                  msg = MESSAGE_CONFIG['account_locked']
                  msg = msg.gsub('${?}', SECURITY_CONFIG['release_account_lock_after'].to_s) if !SECURITY_CONFIG['release_account_lock_after'].nil?

                else
                  # increment the failed login attempts counter
                  usr.failed_login_attempts = usr.failed_login_attempts.next
                
                  if usr.failed_login_attempts >= (SECURITY_CONFIG['max_login_attempts'].to_i - 2)
                    msg = MESSAGE_CONFIG['failed_login_close_to_lockout'].gsub('#{?}', (SECURITY_CONFIG['max_login_attempts'].to_i - usr.failed_login_attempts).to_s)
                  end
                end
          
                usr.save
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
    
    {:user => usr, :message => msg}
  end
  
end
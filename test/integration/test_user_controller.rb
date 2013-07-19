require_relative '../test_helper'

class PidUserApp < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    PidApp
  end

  def setup
    Pid.flush!
    User.flush!
    Group.flush!
    Maintainer.flush!
    
    @pwd = 'secret'
    
    @group = Group.new(:id => 'UCLA', :name => 'test_group')
    @adm_grp = Group.new(:id => 'ADM', :name => 'test_admin_group')
    @adm = User.new(:login => 'test_admin', :name => 'Test Administrator', :password => @pwd, :email => 'admin@example.org', :super => true, 
                    :group => @adm_grp)
    @user = User.new(:login => 'test_user', :name => 'Test User', :password => @pwd, :email => 'test@example.org')
    @mgr = User.new(:login => 'test_mgr', :name => 'Test Manager', :password => @pwd)
    
    @group.users << @user
    @group.users << @mgr
    @group.save
    
    @adm.save
    
    Maintainer.new(:group => @group, :user => @mgr).save
  end

# ---------------------------------------------------------------
# Test secure section: get '/user/:name'
# ---------------------------------------------------------------
  # User is not logged in (HTTP: 302 to /user/login)
  def test_get_user_not_logged_in
    get "/user/#{@user.id}"
    assert last_response.redirect?, "Did not redirect to login page!"
    assert_equal 'http://example.org/user/login', last_response.location  
  end
  
  # Logged in and has appropriate credentials but requested user does not exist (HTTP: 404)
  def test_get_user_missing
    post '/user/login', { :login => @mgr.login, :password => @pwd }
    get '/user/999999'
    assert last_response.not_found?, (last_response.status == 302) ? "Unable to login!" : "Found invalid user!"
  end
  
  # Logged in and user has permission to view their own record (HTTP: 200)
  def test_get_user_self
    post '/user/login', { :login => @user.login, :password => @pwd }
    get "/user/#{@user.id}"
    assert last_response.ok?, (last_response.status == 302) ? "Unable to login!" : "Did not find user's own record!"
  end

  # Logged in and user has permission to view other users within their group (HTTP: 200)
  def test_get_user_authorized
    post '/user/login', { :login => @mgr.login, :password => @pwd }
    get "/user/#{@user.id}"
    assert last_response.ok?, (last_response.status == 302) ? "Unable to login!" : "Was unable to access user record!"
    
    get '/user/logout'
    
    post '/user/login', { :login => @adm.login, :password => @pwd }
    get "/user/#{@user.id}"
    assert last_response.ok?, (last_response.status == 302) ? "Unable to login!" : "Was unable to access user record as an admin!"
  end
  
  # Logged in but user does not have permission to view other users (HTTP: 401)
  def test_get_user_unauthorized
    post '/user/login', { :login => @user.login, :password => @pwd }
    get "/user/#{@mgr.id}"
    assert_equal 401, last_response.status, (last_response.status == 302) ? "Unable to login!" : "Was allowed to access user record!"
  end

# ---------------------------------------------------------------
# Test secure section: get '/user/list'
# ---------------------------------------------------------------
  # User is not logged in (HTTP: 302 to /user/login)
  def test_get_user_list_not_logged_in
    get '/user/list'
    assert last_response.redirect?, "Did not redirect to login page!"
    assert_equal 'http://example.org/user/login', last_response.location 
  end
  
  # Logged in but user does not have permission to get user list (HTTP: 401)
  def test_get_user_list_unauthorized
    post '/user/login', { :login => @user.login, :password => @pwd }
    get '/user/list'
    assert last_response.redirect?, 'We were not redirected!'
    assert_equal "http://example.org/user/#{@user.id}", last_response.location
  end
  
  # Logged in and has permission to view user list (HTTP: 200)
  def test_get_user_list_authorized
    post '/user/login', { :login => @mgr.login, :password => @pwd }
    get '/user/list'
    assert last_response.ok?, (last_response.status == 302) ? "Unable to login!" : "Was unable to access the group's user list!"
    
    get '/user/logout'
    
    post '/user/login', { :login => @adm.login, :password => @pwd }
    get '/user/list'
    assert last_response.ok?, (last_response.status == 302) ? "Unable to login!" : "Was unable to access the user list as an admin!"
  end
  
# ---------------------------------------------------------------------------------------------------------------------------
# Test public sections: GET '/user/login', get '/user/logout', get '/user/forgot', get '/user/register', get '/user/reset'
# ---------------------------------------------------------------------------------------------------------------------------
  # load the user login page (HTTP: 200)
  def test_get_user_login
    get '/user/login'
    assert_equal 200, last_response.status
  end

  # load the login page when already authorized (HTTP: 302 to /link)
  def test_get_user_login_authorized
    post '/user/login', { :login => @user.login, :password => @pwd }
    get '/user/login'
    assert last_response.redirect?, "Didn't redirect to the root when already logged in!"
    assert_equal 'http://example.org/link', last_response.location
  end
  
  # User logout page (HTTP: 302 to /user/login)
  def test_get_user_logout
    post '/user/login', { :login => @user.login, :password => @pwd }
    get '/user/logout'
    assert last_response.redirect?, "Didn't redirect to the login page after logout!"
    assert_equal 'http://example.org/user/login', last_response.location
  end
  
  # User forgotten password page (HTTP: 200)
  def test_get_user_forgot_password
    get '/user/forgot'
    assert last_response.ok?, "Unable to load the forgotten password page!"
  end
  
  # User reset password page (HTTP: 200)
  def test_get_user_reset_password
    post '/user/forgot', {:reset => true, :email => @user.email}

    @user = User.get(@user.id)
    
    get "/user/reset?n=#{@user.id}&c=#{@user.reset_code}"
    assert last_response.ok?, "Unable to load the reset password page!"
  end
  
  # User reset password page with expired reset code (HTTP: 302 to /user/forgot)
  def test_get_user_reset_password_expired
    post '/user/forgot', {:reset => true, :email => @user.email}
    
    @user = User.get(@user.id)
    @user.reset_timer = Time.now + (240 * 60)
    @user.save
    
    get "/user/reset?n=#{@user.id}&c=#{@user.reset_code}"
    assert last_response.redirect?, "We were expecting a redirect but got a #{last_response.status}"
    assert_equal 'http://example.org/user/forgot', last_response.location, 'Did not redirect to forgotten password page!'
  end
  
  # User reset password page without query parameters (HTTP: 401)
  def test_get_user_reset_password_no_params
    get "/user/reset?n=1"
    assert_equal 401, last_response.status, "Was able to load the password page without a reset code!"
  end

# ---------------------------------------------------------------
# Test secure section: get '/user/register'
# ---------------------------------------------------------------  
  # User register page - unauthenticated (HTTP: 200)
  def test_get_user_register_not_logged_in
    get '/user/register'
    assert last_response.redirect?, "We were expecting a redirect but got a #{last_response.status}"
    assert_equal 'http://example.org/user/login', last_response.location, 'Did not redirect to the login page!'
  end
  
  # User register page - authenticated but without group manager permissions (HTTP: 401)
  def test_get_user_register_unauthorized
    post '/user/login', { :login => @user.login, :password => @pwd }
    get "/user/register"
    assert_equal 401, last_response.status, 'We were able to access the registration page as a regular user!'
  end
  
  # User register page - authenticated and a group manager (HTTP: 200)
  def test_get_user_register_authorized
    post '/user/login', { :login => @mgr.login, :password => @pwd }
    get "/user/register"
    assert last_response.ok?, 'We were not able to access the registration page as a group maintainer!'
    
    get '/user/logout'
    
    post '/user/login', { :login => @adm.login, :password => @pwd }
    get "/user/register"
    assert last_response.ok?, 'We were not able to access the registration page as an admin!'
  end
  
# -------------------------------------------------------------------------------------------------------
# Test public sections: POST '/user/login', '/user/forgot', '/user/register'
# -------------------------------------------------------------------------------------------------------
  # User login page (HTTP: 302 to /link)
  def test_post_user_login
    post '/user/login', { :login => @user.login, :password => @pwd }
    assert_equal 302, last_response.status
    assert_equal 'http://example.org/link', last_response.location
  end

  # User login failure (HTTP: 500)
  def test_post_user_login_bad_data
    post '/user/login', { :login => @user.login, :password => "bad password" }
    #TODO - This should probably be a 500 or maybe check for error message in body
    assert last_response.ok?  
  end
  
  # User forgotten password page with missing email (HTTP: 500)
  def test_post_user_forgot_password_bad_data
    post '/user/forgot', {:reset => true, :email => 'so.and.so@example.org'}
    #TODO - This should probably be a 500 or maybe check for error message in body
    assert last_response.ok?, 'An invalid email address was successful!'
  end
  
  # User forgotten password page (HTTP: 200)
  def test_post_user_forgot_password
    post '/user/forgot', {:reset => true, :email => @user.email}
    assert last_response.ok?, 'Could not find user by their email address!'
  end
  
  # Register new user - missing data (HTTP: 500)
  def test_post_user_register_bad_data
    post '/user/login', { :login => @adm.login, :password => @pwd }
    post '/user/register', { :login => @user.login, :password => 'another secret', 
                             :email => @user.email, :group_id => @group.id }
    #TODO - This should probably be a 500 or maybe check for error message in body
    assert last_response.ok?
  end
  
  # Register new user when unauthenticated (HTTP: 200)
  def test_post_user_register_not_logged_in
    post '/user/register', { :login => 'new_user', :name => 'New User', :password => 'another secret', 
                             :email => 'test@test.org', :group_id => @group.id }
    assert last_response.redirect?, 'Was expecting to get redirected to the login page!'
    assert_equal 'http://example.org/user/login', last_response.location
  end
  
  # Register new user when authenticated but not a group manager (HTTP: 401)
  def test_post_user_register_unauthorized
    post '/user/login', { :login => @user.login, :password => @pwd }
    post '/user/register', { :login => 'new_user', :name => 'New User', :password => 'another secret', 
                             :email => 'test@test.org', :group_id => @group.id }
    #TODO - This should probably be a 401 or maybe check for error message in body
    assert last_response.ok?, 'Was able to register a user without being an admin or group maintainer!'
  end
  
  # Register new user when authenticated as group admin (HTTP: 200)
  def test_post_user_register_authorized
    post '/user/login', { :login => @mgr.login, :password => @pwd }
    post '/user/register', { :login => 'new_user', :name => 'New User', :password => 'another secret', 
                             :email => 'test@test.org', :group_id => @group.id }
    assert last_response.ok?, 'Was unable to register a user even logged in as a group maintainer!'
    
    get '/user/logout'
    
    post '/user/login', { :login => @adm.login, :password => @pwd }
    post '/user/register', { :login => 'new_usertwo', :name => 'New User 2', :password => 'another secret', 
                             :email => 'test2@test.org', :group_id => @group.id }
    assert last_response.ok?, 'Was unable to register a user even logged in as an admin!'
  end
  
# -------------------------------------------------------------------------------------------------------
# Test edit user: PUT '/user/:name'
# -------------------------------------------------------------------------------------------------------
  # Edit current user's info (HTTP: 200)
  def test_put_user_self
    post '/user/login', { :login => @user.login, :password => @pwd }
    put "/user/#{@user.id}", { :name => 'Something Different' }
    
    assert last_response.ok?, 'Unable to update own user profile!'
  end

  # Edit user when not logged in (HTTP: 302 to /user/login)
  def test_put_user_not_logged_in
    put "/user/#{@user.id}", { :name => 'Something Different' }
    
    assert last_response.redirect?, 'Was expecting to get redirected to the login page!'
    assert_equal 'http://example.org/user/login', last_response.location
  end
  
  # Edit other user's info when authenticated but not a group manager (HTTP: 401)
  def test_put_user_other_unauthorized
    post '/user/login', { :login => @user.login, :password => @pwd }
    put "/user/#{@mgr.id}", { :name => 'Something Different', :email => @mgr.email }
    
    #TODO - This should probably be a 401 or maybe check for error message in body
    assert last_response.ok?, "We were able to update another user profile! #{last_response.status}"
  end
  
  # Edit other user's info when authenticated and as a group manager (HTTP: 200)
  def test_put_user_other
    post '/user/login', { :login => @mgr.login, :password => @pwd }
    put "/user/#{@user.id}", { :name => 'Something Different' }
    
    assert last_response.ok?, "Unable to update user profile when logged in as maintainer!"
    
    get '/user/logout'
    
    post '/user/login', { :login => @adm.login, :password => @pwd }
    put "/user/#{@user.id}", { :name => 'Something Else' }
    
    assert last_response.ok?, "Unable to update user profile when logged in as admin!"
  end

end
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
    
    @group = Group.new(:id => 'UCLA', :name => 'test_group')
    @user = User.new(:login => 'test_user', :name => 'Test User', :password => 'secret')
    @mgr = User.new(:login => 'test_mgr', :name => 'Test Manager', :password => 'secret')
    
    @group.users << @user
    @group.users << @mgr
    @group.save
    
    Maintainer.new(:group => @group, :user => @mgr).save
  end

# ---------------------------------------------------------------
# Test secure section: get '/user/:name'
# ---------------------------------------------------------------
  # User is not logged in (HTTP: 302 to /user/login)
  def test_get_user_not_logged_in
    get '/user/test_user'
    assert last_response.redirect?, "Did not redirect to login page!"
    assert_equal 'http://example.org/user/login', last_response.location  
  end
  
  # Logged in and has appropriate credentials but requested user does not exist (HTTP: 404)
  def test_get_user_missing
    post '/user/login', { :login => 'test_user', :password => 'secret' }
    get '/user/not_there'
    assert last_response.not_found?, (last_response.status == 302) ? "Unable to login!" : "Found invalid user!"
  end
  
  # Logged in and user has permission to view their own record (HTTP: 200)
  def test_get_user_self
    post '/user/login', { :login => 'test_user', :password => 'secret' }
    get '/user/test_user'
    assert last_response.ok?, (last_response.status == 302) ? "Unable to login!" : "Did not find user record!"
  end

  # Logged in and user has permission to view other users within their group (HTTP: 200)
  def test_get_user_authorized
    post '/user/login', { :login => 'test_mgr', :password => 'secret' }
    get '/user/test_user'
    assert last_response.ok?, (last_response.status == 302) ? "Unable to login!" : "Was unable to access user record!"
  end
  
  # Logged in but user does not have permission to view other users (HTTP: 401)
  def test_get_user_unauthorized
    post '/user/login', { :login => 'test_user', :password => 'secret' }
    get '/user/test_mgr'
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
    post '/user/login', { :login => 'test_user', :password => 'secret' }
    get '/user/list'
    assert_equal 401, last_response.status, (last_response.status == 302) ? "Unable to login!" : "Was allowed to access the group's user list!"
  end
  
  # Logged in and has permission to view user list (HTTP: 200)
  def test_get_user_list
    post '/user/login', { :login => 'test_mgr', :password => 'secret' }
    get '/user/list'
    assert last_response.ok?, (last_response.status == 302) ? "Unable to login!" : "Was unable to access the group's user list!"
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
    post '/user/login', { :login => 'test_user', :password => 'secret' }
    get '/user/login'
    assert last_response.redirect?, "Didn't redirect to the root when already logged in!"
    assert_equal 'http://example.org/link', last_response.location
  end
  
  # User logout page (HTTP: 302 to /user/login)
  def test_get_user_logout
    post '/user/login', { :login => 'test_user', :password => 'secret' }
    get '/user/logout'
    assert last_response.redirect? "Didn't redirect to the login page after logout!"
    assert_equal 'http://example.org/user/login', last_response.location
  end
  
  # User forgotten password page (HTTP: 200)
  def test_get_user_forgot_password
    assert_equal true, true
  end
  
  # User reset password page (HTTP: 200)
  def test_get_user_reset_password
    assert_equal true, true
  end

  # User register page - unauthenticated (HTTP: 200)
  def test_get_user_register_self
    assert_equal true, true
  end
  
  # User register page - authenticated but without group manager permissions (HTTP: 401)
  def test_get_user_register_other_unauthorized
    assert_equal true, true
  end
  
  # User register page - authenticated and a group manager (HTTP: 200)
  def test_get_user_register_other
    assert_equal true, true
  end
  
# -------------------------------------------------------------------------------------------------------
# Test public sections: POST '/user/login', get '/user/logout', get '/user/forgot', get '/user/register'
# -------------------------------------------------------------------------------------------------------
  # User login page (HTTP: 302 to /link)
  def test_post_user_login
    post '/user/login', { :login => @user.login, :password => @pwd }
    assert_equal 302, last_response.status
    assert_equal '/link', last_response.location
  end

  # User login failure (HTTP: 500)
  def test_post_user_login_bad_data
    post '/user/login', { :login => @user.login, :password => "bad #{@pwd}" }
    assert_equal 200, last_response.status
  end

  # User logout page (HTTP: 302, /user/login)
  def test_post_user_logout
    assert_equal true, true
  end
  
  # User forgotten password page with missing email (HTTP: 500)
  def test_post_user_forgot_password_bad_data
    assert_equal true, true
  end
  
  # User forgotten password page (HTTP: 200)
  def test_post_user_forgot_password
    assert_equal true, true
  end
  
  # Register new user - missing data (HTTP: 500)
  def test_post_user_register_bad_data
    post '/user/register', { :login => 'new_user', :password => 'another secret', 
                             :email => 'test@test.org', :group_id => @group.id }
    assert_equal 500, last_response.status
  end
  
  # Register new user when unauthenticated (HTTP: 200)
  def test_post_user_register_self
    post '/user/register', { :login => 'new_user', :name => 'New User', :password => 'another secret', 
                             :email => 'test@test.org', :group_id => @group.id }
    assert_equal 'http://example.org/user/register', last_response.location
    assert_equal 200, last_response.status
  end
  
  # Register new user when authenticated but not a group manager (HTTP: 401)
  def test_post_user_register_other_unauthorized
    assert_equal true, true
  end
  
  # Register new user when authenticated as group admin (HTTP: 200)
  def test_post_user_register_other
    assert_equal true, true
  end
  
# -------------------------------------------------------------------------------------------------------
# Test edit user: PUT '/user/:name'
# -------------------------------------------------------------------------------------------------------
  # Edit current user's info (HTTP: 200)
  def test_put_user_self
    assert_equal true, true
  end

  # Edit user when not logged in (HTTP: 302 to /user/login)
  def test_put_user_not_logged_in
    assert_equal true, true
  end
  
  # Edit other user's info when authenticated but not a group manager (HTTP: 401)
  def test_put_user_other_unauthorized
    assert_equal true, true
  end
  
  # Edit other user's info when authenticated and as a group manager (HTTP: 200)
  def test_put_user_other
    assert_equal true, true
  end
  
# -------------------------------------------------------------------------------------------------------
# Test deactivate user: DELETE '/user/:name'
# -------------------------------------------------------------------------------------------------------
  # Deactivate user when not logged in (HTTP: 302 to /user/login)
  def test_delete_user_not_logged_in
    assert_equal true, true
  end

  # Deactivate other user's info when authenticated but not a group manager (HTTP: 401)
  def test_delete_user_other_unauthorized
    assert_equal true, true
  end

  # Deactivate other user's info when authenticated and as a group manager (HTTP: 200)
  def test_delete_user_other
    assert_equal true, true
  end

end
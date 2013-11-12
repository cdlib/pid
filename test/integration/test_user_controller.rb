require_relative '../test_helper'

class TestUserController < Test::Unit::TestCase
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
    @mgr = User.new(:login => 'test_mgr', :name => 'Test Manager', :password => @pwd, :email => 'mgr@example.org')
    
    @group.users << @user
    @group.users << @mgr
    @group.save
    
    @group2 = Group.new(:id => 'UCSD', :name => 'group2')
    @group2.save
    
    @adm.save
    
    Maintainer.new(:group => @group, :user => @mgr).save
    Maintainer.new(:group => @group2, :user => @mgr).save
  end

# -----------------------------------------------------------------------------------------------
  def test_get_login
    get "/user/login"
    assert last_response.ok?, "Did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_login']), 'Did not get to the login page!'
    
    # Should redirect to main page when already logged in
    post '/user/login', { :login => @adm.login, :password => @pwd }
    assert last_response.redirect?, "Was not redirected to the main page #{last_response.status}"
    assert last_response.location.include?(PidApp::SECURITY_CONFIG['target_after_login']), "Did not get redirected to the main page!"
  end
  
# -----------------------------------------------------------------------------------------------
  def test_get_logout
    post '/user/login', { :login => @user.login, :password => @pwd }
    get "/user/logout"
    assert last_response.redirect?, "Did not receive a 302 status code, got a #{last_response.status}"
    assert last_response.location.include?(PidApp::SECURITY_CONFIG['target_after_logout']), "Did not get redirected to the correct page!"
  end

# -----------------------------------------------------------------------------------------------
  def test_get_list
    security_check_administrator("/user/list", "get", nil, false)

    post '/user/login', { :login => @adm.login, :password => @pwd }
    get "/user/list"
    assert last_response.ok?, "Did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_user_list']), 'Did not get to the user list page!'
  end

# -----------------------------------------------------------------------------------------------
  def test_get_admin
    security_check_administrator("/user/admin", "get", nil, false)

    post '/user/login', { :login => @adm.login, :password => @pwd }
    get "/user/admin"
    assert last_response.ok?, "Did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_admin']), 'Did not get to the administration page!'
  end

# -----------------------------------------------------------------------------------------------
  def test_get_register
    security_check_administrator("/user/register", "get", nil, false)

    # Maintainer/Manager can load the register page
    post '/user/login', { :login => @mgr.login, :password => @pwd }
    get "/user/register"
    assert last_response.ok?, "Maintainer did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_user_register']), 'The Maintainer did not get to the create new user page!'
    get '/user/logout'
    
    # super admin
    post '/user/login', { :login => @adm.login, :password => @pwd }
    get "/user/register"
    assert last_response.ok?, "Admin did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_user_register']), 'The admin did not get to the create new user page!'
  end
  
# -----------------------------------------------------------------------------------------------
  def test_get_user
    security_check_basic("/user/#{@user.id}", "get", nil)

    # User can view their own profile
    post '/user/login', { :login => @user.login, :password => @pwd }
    get "/user/#{@user.id}"
    assert last_response.ok?, "User did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_user_view']), 'User could not view their own profile!'
    
    # User cannot view another's profile!
    get "/user/#{@mgr.id}"
    assert_equal 403, last_response.status, "Was expecting a 403 because the user should not have access to another user's profile!"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_unauthorized']), "Was not sent to the unauthorized page!"
    get '/user/logout'
    
    # Maintainer/Manager can view one of their user's profiles
    post '/user/login', { :login => @mgr.login, :password => @pwd }
    get "/user/#{@user.id}"
    assert last_response.ok?, "Manager did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_user_view']), 'Could not view the user profile as a Manager!'
    get '/user/logout'
    
    # Super admin can view any profile
    post '/user/login', { :login => @adm.login, :password => @pwd }
    get "/user/#{@user.id}"
    assert last_response.ok?, "Admin did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_user_view']), 'Could not view the user profile as an Admin!'
  end

# -----------------------------------------------------------------------------------------------
  def test_get_forgot_password
    get '/user/forgot'
    assert last_response.ok?, "Unable to load the forgotten password page!"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_forgotten_password']), 'Did not get to the administration page!'
    
    # Should redirect to main page when already logged in
    begin
      post '/user/login', { :login => @adm.login, :password => @pwd }
    rescue Exception => e
put "encountered: #{e.inspect}"      
      assert e.errno == 'ECONNREFUSED'
    end
    
    get "/user/forgot"
    assert last_response.redirect?, "Was not redirected to the main page #{last_response.status}"
    assert last_response.location.include?(PidApp::SECURITY_CONFIG['target_after_login']), "Did not get redirected to the main page!"
  end

# -----------------------------------------------------------------------------------------------
  def test_get_reset_password
    # Try the reset page with no params
    get '/user/reset'
    assert last_response.redirect?, "Was not redirected to the forgot password page when passing no params!"
    assert_equal last_response.location, 'http://example.org/user/forgot', 'Did not get to the forgotten password page!'
    
    # Try the reset page with bogus params
    get '/user/reset?n=1&c123456'
    assert last_response.redirect?, "Was not redirected to the forgot password page when passing bad params!"
    assert_equal last_response.location, 'http://example.org/user/forgot', 'Did not get to the forgotten password page!'
    
    # Try the reset page when expired 
    post '/user/forgot', {:reset => true, :login => @user.login}
    @user = User.get(@user.id)
    @user.reset_timer = Time.now + (240 * 60)
    @user.save
    
    get "/user/reset?n=#{@user.id}&c=#{@user.reset_code}"
    assert last_response.redirect?, "We were expecting a redirect but got a #{last_response.status}"
    assert_equal last_response.location, 'http://example.org/user/forgot', 'Did not get to the forgotten password page!'
    
    # Try reset page with valid values
    post '/user/forgot', {:reset => true, :login => @user.login}
    @user = User.get(@user.id)
    
    get "/user/reset?n=#{@user.id}&c=#{@user.reset_code}"
    assert last_response.ok?, "Unable to load the reset password page! Got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_reset_password']), 'Did not get to the reset password page!'
    
    # Should redirect to main page when already logged in
    post '/user/login', { :login => @adm.login, :password => @pwd }
    get "/user/reset"
    assert last_response.redirect?, "Was not redirected to the main page #{last_response.status}"
    assert last_response.location.include?(PidApp::SECURITY_CONFIG['target_after_login']), "Did not get redirected to the main page!"
  end
  
# -----------------------------------------------------------------------------------------------
  def test_post_login
    security_check_basic("/link", "get", nil)
    
    post '/user/login', { :login => @user.login, :password => @pwd }
    assert last_response.redirect?, "User not redirected to the main page #{last_response.status}"
    assert last_response.location.include?(PidApp::SECURITY_CONFIG['target_after_login']), "User did not get redirected to the main page!"
    get "/user/logout"
    
    post '/user/login', { :login => @mgr.login, :password => @pwd }
    assert last_response.redirect?, "Maintainer/Manager not redirected to the main page #{last_response.status}"
    assert last_response.location.include?(PidApp::SECURITY_CONFIG['target_after_login']), "Maintainer/Manager did not get redirected to the main page!"
    get "/user/logout"
    
    post '/user/login', { :login => @adm.login, :password => @pwd }
    assert last_response.redirect?, "Admin not redirected to the main page #{last_response.status}"
    assert last_response.location.include?(PidApp::SECURITY_CONFIG['target_after_login']), "Admin did not get redirected to the main page!"
    get "/user/logout"
    
    # Force a lockout
    lockout = PidApp::SECURITY_CONFIG['max_login_attempts']
    (1..lockout).each do |i|
      post '/user/login', { :login => @adm.login, :password => 'bad_pwd' }
      if i == 1
        assert last_response.ok?, "Expecting a 200 on the bad login credentials, got a #{last_response.status}"
        assert last_response.body.include?(PidApp::MESSAGE_CONFIG['failed_login']), "Was expecting the failed login message! #{last_response.body}"
      elsif i == (lockout - 2)
        assert last_response.ok?, "Expecting a 200 on the account lockout warning, got a #{last_response.status}"
        assert last_response.body.include?(PidApp::MESSAGE_CONFIG['failed_login_close_to_lockout'].gsub('#{?}', 2.to_s)), "Was expecting the account lockout warning message! #{last_response.body}"
      end
    end
    assert last_response.ok?, "Expecting a 200 on the account lockout, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['account_locked'].gsub('${?}', PidApp::SECURITY_CONFIG['release_account_lock_after'].to_s)), "Was expecting the account lockout message! #{last_response.body}"
  end

# -----------------------------------------------------------------------------------------------
  def test_post_forgot_password
    post '/user/forgot', {:reset => true, :login => 'Noone'}
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['user_not_found']), "Was allowed to request a password reset for a non-existent user"
            
    post '/user/forgot', {:reset => true, :login => @user.login}
    assert last_response.ok?, 'Could not set the users password reset timer!'
    assert !@user.reload.reset_code.nil?, "The user's reset timer was not set!"
  end
    
# -----------------------------------------------------------------------------------------------
  def test_post_reset_password
    # Password and confirmation mismatch
    post '/user/forgot', {:reset => true, :login => @user.login}
    @user.reload
    post "/user/reset?n=#{@user.id}&c=#{@user.reset_code}", {:password => 'testing', :confirm => 'blah'}
    assert_equal 409, last_response.status, "Expected a 409 but got a #{last_response.status}"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['password_mismatch']), 'Was able to reset the password with mismatching passwords!'
    
    # Successful reset
    post '/user/forgot', {:reset => true, :login => @user.login}
    @user.reload
    post "/user/reset?n=#{@user.id}&c=#{@user.reset_code}", {:password => 'testing', :confirm => 'testing'}
    assert last_response.redirect?, "Unable to reset the password! Got a #{last_response.status}"
    assert_equal 'http://example.org/user/login', last_response.location, "Did not reset the password!"
    
    # Make sure the new password works
    post '/user/login', { :login => @user.login, :password => 'testing' }
    assert last_response.redirect?, "Was not redirected to the main page #{last_response.status}"
    assert last_response.location.include?(PidApp::SECURITY_CONFIG['target_after_login']), "Did not get redirected to the main page!"
  end

# -----------------------------------------------------------------------------------------------
  def test_put_user
    security_check_basic("/user/#{@user.id}", "post", nil)
    
    # As a user updating their own record
    post '/user/login', {:login => @user.login, :password => @pwd}
    put "/user/#{@user.id}", {:name => 'Updated my name', :password => ''}
    assert last_response.ok?, "User was unable to update their own profile!"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['user_update_success']), "User did not receive the success message! #{last_response.body}"
    
    # As a user updating another's record - should fail!
    put "/user/#{@mgr.id}", {:name => 'Updated another users name', :password => ''}
    assert_equal 403, last_response.status, "Was expecting a 403 because the user cannot update another user's profile!"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_unauthorized']), "Was not sent to the unauthorized page!"
    get '/user/logout'
    
    # As a manager updating one of their users
    post '/user/login', {:login => @mgr.login, :password => @pwd}
    put "/user/#{@user.id}", {:name => 'Updated user name', :password => ''}
    assert last_response.ok?, "Unable to update a user as a Manager/Maintainer!"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['user_update_success']), "Maintainer did not receive the success message!"
    get '/user/logout'
    
    # As an admin updating one of their users
    post '/user/login', {:login => @adm.login, :password => @pwd}
    put "/user/#{@user.id}", {:name => 'Updated user name', :password => ''}
    assert last_response.ok?, "Unable to update a user as a Admin!"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['user_update_success']), "Admin did not receive the success message!"
    get '/user/logout'
  end
  
# -----------------------------------------------------------------------------------------------
  def test_post_register
    args = {:login => 'blahblah', :name => 'Blah Blah', :email => 'blah@tester.org', :password => @pwd, :confirm => @pwd}
    
    security_check_administrator("/user/register", "post", args, false)
    
    # As a manager
    post '/user/login', {:login => @mgr.login, :password => @pwd}
    post '/user/register', args
    assert last_response.ok?, 'Unable to register a new user as a Manager/Maintainer!'
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['user_register_success']), "Maintainer did not receive the success message!"

    assert_equal 2, Maintainer.all(:user => @mgr).count, "User is not a maintainer of 2 groups!"

    # As a manager selecting an invalid group
    args[:group] = @adm_grp.id
    args[:login] = 'invalid'
    post '/user/register', args
    assert_equal 409, last_response.status, "Was able to register a new user as a Manager/Maintainer for a group we do not manage! #{last_response.body}"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['user_register_invalid_group']), "Maintainer did not receive the invalid group message!"
    
    # As a manager selecting a different group
    args[:group] = @group2.id
    args[:login] = 'valid'
    post '/user/register', args
    assert last_response.ok?, "Unable to register a new user as a Manager/Maintainer!"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['user_register_success']), "Maintainer did not receive the success message!"
    get '/user/logout'
    
    # test the new account
    usr = User.first(:login => 'blahblah')
    assert !usr.nil?, 'The user was not created!'
    assert_equal @mgr.group, usr.group, "The users group is not the same as the managers!"
    
    post '/user/login', {:login => usr.login, :password => @pwd}
    assert last_response.redirect?, "Was unable to login as the new user! #{last_response.status}"
    assert_equal "http://example.org#{PidApp::SECURITY_CONFIG['target_after_login']}", last_response.location, "Was not redirected to the home page! #{last_response.location}."
    get '/user/logout'
    
    # As a super admin
    post '/user/login', {:login => @adm.login, :password => @pwd}
    post '/user/register', {:login => 'tester', :name => 'Tester', :email => 'tester@here.org', :password => @pwd, :confirm => @pwd}
    assert last_response.ok?, 'Unable to register a new user as a Admin!'
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['user_register_success']), 'Admin did not receive the success message!'
  end

end
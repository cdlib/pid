require_relative '../test_helper'

class PidGroupApp < Test::Unit::TestCase
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
    
    @adm.save
    
    Maintainer.new(:group => @group, :user => @mgr).save
  end

# ---------------------------------------------------------------
# Test security 
# ---------------------------------------------------------------
  # User is not logged in (HTTP: 302 to /user/login)
  def test_get_group_list_not_logged_in
    # not logged in
    get "/group/list"
    assert last_response.redirect?, "Did not redirect to login page!"
    assert_equal 'http://example.org/user/login', last_response.location, 'Was not sent to the login page!' 
    
    # logged in as a non super admin should fail
    post '/user/login', { :login => @user.login, :password => @pwd }
    get "/group/list"
    assert_equal 'http://example.org/unauthorized', last_response.location, 'Was not sent to the unauthorized page!' 
    post '/user/logout'
  end

# ---------------------------------------------------------------
# Test page loads
# ---------------------------------------------------------------
  def test_get_group_list
    post '/user/login', { :login => @adm.login, :password => @pwd }
    
    get "/group/list"
    assert last_response.ok?, "Did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_group_list']), 'Did not get to the group list page!'
  end
  
  def test_get_group
    post '/user/login', { :login => @adm.login, :password => @pwd }
    
    get "/group/#{@group.id}"
    assert last_response.ok?, "Did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_group_view']), 'Did not get to the group page!'
  end
  
# ---------------------------------------------------------------
# Test update 
# ---------------------------------------------------------------
  def test_put_group
    # bad data
    
    # good data
  end

# ---------------------------------------------------------------
# Test delete group
# ---------------------------------------------------------------
  def test_delete_group
    # with existing users/managers
    
    # without users/managers
  end

# ---------------------------------------------------------------
# Test manage maintainers and users
# ---------------------------------------------------------------
  def test_group_add_manager
    # duplicate manager
    
    # good data
  end
  
  def test_group_add_user
    # duplicate user
    
    # good data
  end
  
  def test_remove_manager
    # missing manager
    
    # good data
  end
  
  def test_remove_user
    # missing user
    
    # good data
  end
end
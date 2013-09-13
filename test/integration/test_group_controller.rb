require_relative '../test_helper'

class TestGroupController < Test::Unit::TestCase
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
    @user2 = User.new(:login => 'test_user2', :name => 'Test User 2', :password => @pwd, :email => 'test2@example.org')
    @mgr = User.new(:login => 'test_mgr', :name => 'Test Manager', :password => @pwd, :email => 'mgr@example.org')
    
    @group.users << @user
    @group.users << @mgr
    @group.save
    
    @user2.save
    @adm.save
    
    Maintainer.new(:group => @group, :user => @mgr).save
  end

# --------------------------------------------------------------------------------------------------------------
  def test_get_list
    security_check_administrator("/group/list", "get", nil, true)

    post '/user/login', { :login => @adm.login, :password => @pwd }
    get "/group/list"
    assert last_response.ok?, "Did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_group_list']), 'Did not get to the group list page!'
  end
  
# --------------------------------------------------------------------------------------------------------------
  def test_get_new
    security_check_administrator("/group/new", "get", nil, true)

    post '/user/login', { :login => @adm.login, :password => @pwd }
    get "/group/new"
    assert last_response.ok?, "Did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_group_create']), 'Did not get to the new group page!'
  end

# --------------------------------------------------------------------------------------------------------------
  def test_get_group
    security_check_administrator("/group/#{@group.id}", "get", nil, false)

    # Maintainer should be able to view their own group
    post '/user/login', { :login => @mgr.login, :password => @pwd }
    get "/group/#{@group.id}"
    assert last_response.ok?, "Did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_group_view']), 'Did not get to the group page!'
    post '/user/logout'
    
    post '/user/login', { :login => @adm.login, :password => @pwd }
    get "/group/#{@group.id}"
    assert last_response.ok?, "Did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_group_view']), 'Did not get to the group page!'
  end

# --------------------------------------------------------------------------------------------------------------
  def test_put_group
    security_check_administrator("/group/#{@group.id}", "put", {:name => 'Updated Name', :description => 'Testing changes'}, false)

    # Maintainer should be able to edit their own group
    post '/user/login', { :login => @mgr.login, :password => @pwd }
    put "/group/#{@group.id}", {:name => 'Updated Name 1', :description => 'Testing changes first'}
    assert last_response.ok?, "Did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_group_view']), 'Did not get to the group page!'
    assert_equal 'Updated Name 1', Group.first(:id => @group.id).name, 'The changes were not saved!'
    post '/user/logout'

    # logged in as a super admin
    post '/user/login', { :login => @adm.login, :password => @pwd }
    put "/group/#{@group.id}", {:name => 'Updated Name 2', :description => 'Testing changes again'}
    assert last_response.ok?, "Did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_group_view']), 'Did not get to the group page!'
    assert_equal 'Updated Name 2', Group.first(:id => @group.id).name, 'The changes were not saved!'
  end

# --------------------------------------------------------------------------------------------------------------
  def test_post_group
    security_check_administrator("/group/new", "post", {:id => 'TEST', :name => 'Updated Name', :description => 'Testing changes'}, true)

    # logged in as a super admin
    post '/user/login', { :login => @adm.login, :password => @pwd }
    post "/group", {:id => 'TEST', :name => 'Name', :description => 'Testing create'}
    assert last_response.ok?, "Did not receive a 200 status code, got a #{last_response.status}"
    assert !Group.first(:id => 'TEST').nil?, "The changes were not saved! #{last_response.body}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_group_view']), 'Did not get to the group page!'
    
    # Duplicate
    post "/group", {:id => @group.id, :name => 'Name', :description => 'Testing duplicate'}
    assert_equal 409, last_response.status, "Did not receive a 409 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['group_create_duplicate']), 'Did not get to the duplicate group message!'
    
    # Missing ID
    post "/group", {:name => 'Name', :description => 'Testing create'}
    assert_equal 500, last_response.status, "Did not receive a 500 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['group_create_failure']), 'Did not get to the failure message!'
    
    get '/user/logout'
  end

# --------------------------------------------------------------------------------------------------------------
  def test_delete_group
    security_check_administrator("/group/delete", "delete", {:id => @group.id}, true)

    # logged in as a super admin
    post '/user/login', { :login => @adm.login, :password => @pwd }
    delete "/group/UNKNOWN"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_not_found']), 'Was able to delete a non-existent group!'

    delete "/group/#{@group.id}"
    assert_equal 409, last_response.status, "Was able to delete the group when it had associated users/maintainers! #{last_response.status}"
    
    Group.new(:id => 'TEST', :name => 'Test Group', :description => 'testing').save
    delete "/group/TEST"
    assert last_response.ok?, 'Unable to delete the group!'
    assert Group.first(:id => 'TEST').nil?, 'The group was not deleted!'
  end

# --------------------------------------------------------------------------------------------------------------
  def test_add_user_to_group
    security_check_administrator("/group/#{@group.id}/user/#{@adm.id}", "post", nil, false)

    # logged in as a maintainer
    post '/user/login', { :login => @mgr.login, :password => @pwd }
    post "/group/#{@group.id}/user/#{@adm.id}"
    assert last_response.ok?, "Unable to add the user to the group! Got a #{last_response.status}"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['group_add_maintainer_success']), 'Did not receive the success message!' 
    
    # Adding a user that is already attached to that group should fail
    post "/group/#{@group.id}/user/#{@user.id}"
    assert_equal 409, last_response.status, 'Was able to add a duplicate user!'
    post '/user/logout'

    # logged in as a super admin
    post '/user/login', { :login => @adm.login, :password => @pwd }
    post "/group/#{@group.id}/user/#{@user2.id}"
    assert last_response.ok?, "Unable to add the user to the group! Got a #{last_response.status}"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['group_add_maintainer_success']), 'Did not receive the success message!' 
  end

# --------------------------------------------------------------------------------------------------------------
  def test_remove_user_from_group
    security_check_administrator("/group/#{@group.id}/user/#{@adm.id}", "delete", nil, false)

    # logged in as a maintainer
    post '/user/login', { :login => @mgr.login, :password => @pwd }
    delete "/group/#{@group.id}/user/#{@user.id}"
    assert last_response.ok?, "Unable to remove the user from the group! Got a #{last_response.status} #{last_response.body}"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['group_remove_user_success']), 'Did not receive the success message!' 
    
    # Adding a user that is already a manager should fail
    delete "/group/#{@group.id}/user/#{@adm.id}"
    assert_equal 409, last_response.status, 'Was able to remove a user that isnt associated with the group!'
    post '/user/logout'

    # logged in as a super admin
    post '/user/login', { :login => @adm.login, :password => @pwd }
    delete "/group/#{@group.id}/user/#{@mgr.id}"
    assert last_response.ok?, "Unable to remove the user from the group! Got a #{last_response.status} #{last_response.body}"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['group_remove_user_success']), 'Did not receive the success message!' 
  end

# --------------------------------------------------------------------------------------------------------------
  def test_add_maintainer_to_group
    security_check_administrator("/group/#{@group.id}/maintainer/#{@adm.id}", "post", nil, false)

    # logged in as a maintainer
    post '/user/login', { :login => @mgr.login, :password => @pwd }
    post "/group/#{@group.id}/maintainer/#{@adm.id}"
    assert last_response.ok?, "Unable to add the user as a maintainer of the group! Got a #{last_response.status}"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['group_add_maintainer_success']), 'Did not receive the success message!' 
    
    # Adding a user that is already a manager should fail
    post "/group/#{@group.id}/maintainer/#{@mgr.id}"
    assert_equal 409, last_response.status, 'Was able to add a duplicate maintainer!'
    post '/user/logout'

    # logged in as a super admin
    post '/user/login', { :login => @adm.login, :password => @pwd }
    post "/group/#{@group.id}/maintainer/#{@user.id}"
    assert last_response.ok?, "Unable to add the user as a maintainer of the group! Got a #{last_response.status}"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['group_add_maintainer_success']), 'Did not receive the success message!' 
  end

# --------------------------------------------------------------------------------------------------------------
  def test_remove_maintainer_from_group
    security_check_administrator("/group/#{@group.id}/maintainer/#{@adm.id}", "delete", nil, false)

    Maintainer.new(:group => @group, :user => @adm).save
    
    # logged in as a maintainer
    post '/user/login', { :login => @mgr.login, :password => @pwd }
    delete "/group/#{@group.id}/maintainer/#{@mgr.id}"
    assert_equal 409, last_response.status, "Was able to remove self as a maintainer of the group!"
    
    delete "/group/#{@group.id}/maintainer/#{@adm.id}"
    assert last_response.ok?, "Unable to remove the user as a maintainer of the group! Got a #{last_response.status} #{last_response.body}"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['group_remove_maintainer_success']), 'Did not receive the success message!' 
    
    # Adding a user that is already a manager should fail
    delete "/group/#{@group.id}/maintainer/#{@adm.id}"
    assert_equal 409, last_response.status, 'Was able to remove a maintainer that isnt associated with the group!'
    post '/user/logout'

    # logged in as a super admin
    post '/user/login', { :login => @adm.login, :password => @pwd }
    delete "/group/#{@group.id}/maintainer/#{@mgr.id}"
    assert last_response.ok?, "Unable to remove the user as a maintainer of the group! Got a #{last_response.status} #{last_response.body}"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['group_remove_maintainer_success']), 'Did not receive the success message!' 
  end

end
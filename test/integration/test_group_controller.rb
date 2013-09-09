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
    @mgr = User.new(:login => 'test_mgr', :name => 'Test Manager', :password => @pwd, :email => 'mgr@example.org')
    
    @group.users << @user
    @group.users << @mgr
    @group.save
    
    @adm.save
    
    Maintainer.new(:group => @group, :user => @mgr).save
  end

  def test_get_list
    security_check("/group/list", "get", nil)

    # logged in as a maintainer, so the list should not load!
    post '/user/login', { :login => @user.login, :password => @pwd }
    get "/group/list"
    assert_equal 'http://example.org/unauthorized', last_response.location, 'Was not sent to the unauthorized page!' 
    post '/user/logout'

    post '/user/login', { :login => @adm.login, :password => @pwd }
    get "/group/list"
    assert last_response.ok?, "Did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_group_list']), 'Did not get to the group list page!'
  end

  def test_get_new
    security_check("/group/new", "get", nil)

    # logged in as a maintainer should fail, maintainers cannot create groups!
    post '/user/login', { :login => @user.login, :password => @pwd }
    get "/group/new"
    assert_equal 'http://example.org/unauthorized', last_response.location, 'Was not sent to the unauthorized page!' 
    post '/user/logout'

    post '/user/login', { :login => @adm.login, :password => @pwd }
    get "/group/new"
    assert last_response.ok?, "Did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_group_create']), 'Did not get to the new group page!'
  end

  def test_get_group
    security_check("/group/#{@group.id}", "get", nil)

    # logged in as a maintainer so it should fail
    post '/user/login', { :login => @user.login, :password => @pwd }
    get "/group/#{@group.id}"
    assert_equal 'http://example.org/unauthorized', last_response.location, 'Was not sent to the unauthorized page!' 
    post '/user/logout'

    post '/user/login', { :login => @adm.login, :password => @pwd }
    get "/group/#{@group.id}"
    assert last_response.ok?, "Did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_group_view']), 'Did not get to the group page!'
  end

  def test_put_group
    security_check("/group/#{@group.id}", "put", {:name => 'Updated Name', :description => 'Testing changes'})

    # logged in as a maintainer, so it should fail
    post '/user/login', { :login => @user.login, :password => @pwd }
    put "/group/#{@group.id}", {:name => 'Updated Name', :description => 'Testing changes'}
    assert_equal 'http://example.org/unauthorized', last_response.location, 'Was not sent to the unauthorized page!' 
    post '/user/logout'

    # logged in as a super admin
    post '/user/login', { :login => @adm.login, :password => @pwd }
    put "/group/#{@group.id}", {:name => 'Updated Name 2', :description => 'Testing changes again'}
    assert last_response.ok?, "Did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_group_view']), 'Did not get to the group page!'
    assert_equal 'Updated Name 2', Group.first(:id => @group.id).name, 'The changes were not saved!'
  end

  def test_post_group
    security_check("/group/new", "post", {:id => 'TEST', :name => 'Updated Name', :description => 'Testing changes'})

    # logged in as a maintainer, so it should fail
    post '/user/login', { :login => @user.login, :password => @pwd }
    post "/group/new", {:id => 'TEST', :name => 'Updated Name', :description => 'Testing changes'}
    assert_equal 'http://example.org/unauthorized', last_response.location, 'Was not sent to the unauthorized page!' 
    post '/user/logout'

    # logged in as a super admin
    post '/user/login', { :login => @adm.login, :password => @pwd }
    post "/group/new", {:id => 'TEST', :name => 'Updated Name', :description => 'Testing changes'}
    assert last_response.ok?, "Did not receive a 200 status code, got a #{last_response.status}"
    assert !Group.first(:id => 'TEST').nil?, 'The changes were not saved!'
  end

  def test_delete_group
    security_check("/group/delete", "delete", {:id => @group.id})

    # logged in as a maintainer, so it should fail
    post '/user/login', { :login => @user.login, :password => @pwd }
    delete "/group/delete", {:id => @group.id}
    assert_equal 'http://example.org/unauthorized', last_response.location, 'Was not sent to the unauthorized page!' 
    post '/user/logout'

    # logged in as a super admin
    post '/user/login', { :login => @adm.login, :password => @pwd }
    delete "/group/delete/UNKNOWN"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_not_found']), 'Was able to delete a non-existent group!'

    delete "/group/delete/#{@group.id}"
    assert_equal 409, last_response.status, "Was able to delete the group when it had associated users/maintainers! #{@group.id}"
    
    Group.new(:id => 'TEST', :name => 'Test Group', :description => 'testing').save
    delete "/group/delete/TEST"
    assert last_response.ok?, 'Unable to delete the group!'
    assert Group.first(:id => @group.id).nil?, 'The changes were not saved!'
  end

  def test_add_user_to_group

  end

  def test_remove_user_from_group

  end

  def test_add_maintainer_to_group

  end

  def test_remove_maintainer_from_group

  end

  def security_check(page, method, args)

    def invoke_page(method, page, args)     
      if method == "post"
        post page, args
      elsif method == "put"
        put page, args
      elsif method == "delete"
        delete page, args
      else
        get page 
      end
    end
    
    # not logged in
    invoke_page(method, page, args)
    assert last_response.redirect?, "Did not redirect to login page!"
    assert_equal 'http://example.org/user/login', last_response.location, 'Was not sent to the login page!' 
    
    # logged in as a non super admin or group maintainer should fail
    post '/user/login', { :login => @user.login, :password => @pwd }
    invoke_page(method, page, args)
    assert_equal 'http://example.org/unauthorized', last_response.location, 'Was not sent to the unauthorized page!' 
    post '/user/logout'
  end
end
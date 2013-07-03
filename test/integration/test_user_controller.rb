require_relative '../test_helper'

class PidManageApp < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    PidApp
  end

  def setup
    Pid.flush!
    @group = Group.new(:id => 'UCLA', :name => 'test_group')
    @user = User.new(:login => 'test_user', :name => 'Test User', :password => 'secret')
    @group.users << @user
    @group.save
  end

  def test_show_user_404
    get '/user/not_there'
    assert_equal 404, last_response.status
  end
  
  def test_show_user
    get '/user/test_user'
    assert last_response.ok?
  end

  def test_list_all_users
    get '/user/list'
    assert last_response.ok?
  end
  
  def test_new_user
    get '/user/new'
    assert last_response.ok?
  end
  
  def test_user_logout
    get '/user/logout'
    assert_equal 302, last_response.status
  end
  
  def test_user_login
    get '/user/login'
    assert last_response.ok?
  end
  
  def test_login_user
    post '/user/login', { :login => 'test_user', :password => 'secret' }
    assert_equal 'http://example.org/', last_response.location
    assert_equal 302, last_response.status
  end
  
  def test_login_user_with_bad_password
    post '/user/login', { :login => 'test_user', :password => 'bad secret' }
    assert_equal 200, last_response.status
  end
  
  def test_create_new_user
    post '/user/create', { :login => 'new_user', :name => 'New User', :password => 'another secret', 
      :email => 'test@test.org', :group_id => 'UCLA' }
    assert_equal 'http://example.org/user/new_user', last_response.location
    assert_equal 302, last_response.status
  end
  
  def test_create_user_missing_name
    post '/user/create', { :login => 'new_user', :password => 'another secret', 
      :email => 'test@test.org', :group_id => 'UCLA' }
    assert_equal 200, last_response.status
  end
  
end
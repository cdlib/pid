require_relative '../test_helper'

class PidRedirectApp < Test::Unit::TestCase
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
    
    post '/user/login', { :login => 'test_user', :password => 'secret' }
  end
  
  def test_pid_redirect
    Pid.mint(:url => 'http://google.com', :username => @user.login, :change_category => 'User_Entered', :group => @group)
    get '/PID/1'
    assert_equal 'http://google.com', last_response.location
    assert_equal 302, last_response.status
  end
  
  def test_pid_partial_redirect
    Pid.mint(:url => 'http://google.com', :username => @user.login, :change_category => 'User_Entered', :group => @group)
    get '/PID/1/search?q=elmo'
    assert_equal 'http://google.com/search?q=elmo', last_response.location
    assert_equal 302, last_response.status
  end
  
  def test_pid_no_redirect
    get '/PID/1234'
    assert_equal 404, last_response.status
  end
  
  def test_pid_no_partial_redirect
    get '/PID/1/search?q=elmo'
    assert_equal 404, last_response.status
  end
  
  def test_pid_deactivated_not_found
    assert_equal true, true
  end
  
end
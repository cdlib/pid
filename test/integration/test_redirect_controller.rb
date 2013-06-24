require_relative '../test_helper'

class PidRedirectApp < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    PidApp
  end
  
  def setup
    Pid.flush!
    @group = Group.new(:id => 'UCLA', :name => 'test_group')
    @user = User.new(:handle => 'test_user', :name => 'Test User')
    @group.users << @user
    @group.save
  end
  
  def test_pid_redirect
    Pid.mint(:url => 'http://google.com', :username => @user.handle, :change_category => 'User_Entered')
    get '/1'
    assert_equal 'http://google.com', last_response.location
    assert_equal 302, last_response.status
  end
  
  def test_pid_partial_redirect
    Pid.mint(:url => 'http://google.com', :username => @user.handle, :change_category => 'User_Entered')
    get '/1/search?q=elmo'
    assert_equal 'http://google.com/search?q=elmo', last_response.location
    assert_equal 302, last_response.status
  end
  
  def test_pid_no_redirect
    get '/1234'
    assert_equal 404, last_response.status
  end
  
  def test_pid_no_partial_redirect
    get '/1/search?q=elmo'
    assert_equal 404, last_response.status
  end
  
end
require_relative '../test_helper'

class PidManageApp < Test::Unit::TestCase
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
  
  def test_view_pid
    link = Pid.mint(:url => 'http://cdlib.org', :username => @user.handle, :change_category => 'User_Entered')
    get '/link/1'
    assert last_response.ok?
  end
   
  def test_view_404_pid
    link = Pid.mint(:url => 'http://cdlib.org', :username => @user.handle, :change_category => 'User_Entered')
    get '/link/1234'
    assert !last_response.ok?
  end
  
  def test_view_404_pid
    link = Pid.mint(:url => 'http://cdlib.org', :username => @user.handle, :change_category => 'User_Entered')
    get '/link/1234'
    assert !last_response.ok?
  end
  
  def test_new_pid
    get '/link/new'
    assert_equal 200, last_response.status
  end
  
  def test_create_pid
    post '/link', { :url => 'http://cdlib.org' }
    assert_equal 201, last_response.status
  end
  
  def test_create_pid_bad_data
    post '/link', { :url => 'cdlib.org' }
    assert_equal 400, last_response.status
  end
end
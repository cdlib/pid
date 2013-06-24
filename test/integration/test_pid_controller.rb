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
    get '/pid/1'
    assert last_response.ok?
  end
   
  def test_view_404_pid
    link = Pid.mint(:url => 'http://cdlib.org', :username => @user.handle, :change_category => 'User_Entered')
    get '/pid/1234'
    assert !last_response.ok?
  end
  
end
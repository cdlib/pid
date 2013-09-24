require_relative '../test_helper'

class TestInterested < Test::Unit::TestCase
  def setup
    Pid.flush!
    @group = Group.new(:id => 'TEST', :name => 'test_group')
    @group.save

    @group2 = Group.new(:id => 'Test 2', :name => 'test group 2')
    @group2.save

    @user = User.new(:login => 'test_user', :name => 'Test User 1', :email => 'test.user@example.org', :group => @group, :password => 'secret')

    Pid.mint(:url => 'http://ww.yahoo.com', :username => @user.login, :change_category => 'Test', :group => @group).save
    Pid.mint(:url => 'http://www.yahoo.com/1', :username => @user.login, :change_category => 'Test', :group => @group).save
    @pid = Pid.mint(:url => 'http://www.google.com', :username => @user.login, :change_category => 'Test', :group => @group)
    @pid.save
  end
  
# ----------------------------------------------------------------------------------------------- 
  def test_create_new
    interested = Interested.new(:pid => @pid, :group => @group2)

    # Make sure we were able to create the interested party
    assert interested.save, 'Unable to create a new interested parties association!'

    # Make sure that we cannot add the owner of a PID as an interested party of that PID
    assert_raise(DataMapper::SaveFailureError){ Interested.new(:pid => @pid, :group => @group).save }
    
    # Make sure we cannot add a duplicate
    assert_raise(DataObjects::IntegrityError){ Interested.new(:pid => @pid, :group => @group2).save }
  end

# ----------------------------------------------------------------------------------------------- 
  def test_delete
    interested = Interested.new(:pid => @pid, :group => @group2)
    interested.save

    # Make sure we were able to delete the interested party
    assert interested.destroy, 'Was unable to delete the interested party association'
  end

end
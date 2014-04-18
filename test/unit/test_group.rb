require_relative '../test_helper'

class TestGroup < Minitest::Test
  def setup
    Pid.flush!
    @group = Group.new(:id => 'TEST', :name => 'test_group')
    @group.save

    @pwd = 'secret'
    
    User.new(:login => 'test_user', :name => 'Test User 1', :email => 'test.user@example.org', :group => @group, :password => @pwd).save
    User.new(:login => 'test_user2', :name => 'Test User 2', :email => 'test.user2@example.org', :group => @group, :password => @pwd).save
    mngr = User.new(:login => 'test_mngr', :name => 'Test Manager', :email => 'test.mngr@example.org', :group => @group, :password => @pwd)
    mngr.save

    Maintainer.new(:user => mngr, :group => @group).save
  end

# -----------------------------------------------------------------------------------------------      
  def test_create_new
    # Make sure the save function is working
    grp = Group.new(:id => 'NEW', :name => 'New Group', 
                    :description => 'This is a new group', :host => '127.0.0.1')
    assert grp.save, 'Unable to create a new group'
    assert_equal 1, Group.count(:id => 'NEW'), "Unable to find the newly created group!"
    
    # Make sure we cannot save a duplicate
    assert_raises(DataMapper::SaveFailureError){Group.new(:id => 'NEW', :name => 'New Group', 
                    :description => 'This is a new group', :host => '127.0.0.1').save}
  end

# -----------------------------------------------------------------------------------------------  
  def test_modify
    # Make sure we can update the group
    @group.name = 'test group modified'
    @group.save
    grp = Group.get('TEST')
    assert_equal 'test group modified', grp.name, 'The change was not saved!'
  end

# -----------------------------------------------------------------------------------------------  
  def test_users
    grp = Group.new(:id => 'NEW', :name => 'New Group', :description => 'This is a new group', :host => '127.0.0.1')
    
    # Assert the ability to attach users to a group
    User.new(:login => 'new_user', :name => 'New User 1', :email => 'new.user@example.org', :group => grp, :password => @pwd).save
    usr = User.new(:login => 'new2_user', :name => 'New User 2', :email => 'new2.user@example.org', :password => @pwd)
    grp.users << usr
    grp.save
    
    assert_equal 2, grp.users.count, "Unable to add both users to the group!"
  end

# -----------------------------------------------------------------------------------------------  
  def test_maintainers
    grp = Group.new(:id => 'NEW', :name => 'New Group', :description => 'This is a new group', :host => '127.0.0.1')
    
    # Assert the ability to attach maintainers to a group
    usr = User.new(:login => 'new_user', :name => 'New User 1', :email => 'new.user@example.org', :password => @pwd)
    usr2 = User.new(:login => 'new2_user', :name => 'New User 2', :email => 'new2.user@example.org', :password => @pwd)
    usr.save
    usr2.save
    
    assert_equal 5, User.count, "The 2 users were not created."
    
    Maintainer.new(:group => grp, :user => usr).save
    Maintainer.new(:group => grp, :user => usr2).save
    
    grp.reload
    
    assert_equal 2, grp.maintainers.count, "Unable to add both maintainers to the group!"
  end
  
# -----------------------------------------------------------------------------------------------  
  def test_delete
    # Try to delete a group that has members
    assert !@group.destroy, 'Was able to delete a group that still had users associated!'

    @group.users.clear
    @group.save 

    # Make sure we were able to clear the group's members
    assert_equal 0, @group.users.size, 'Unable to remove all user associations with the group!'

    # Try to delete the group when it still has a maintainer
    assert !@group.destroy, 'Was able to delete a group that still had a maintainer associated!'

    Maintainer.all(:group => @group).each do |maintainer|
      maintainer.destroy
    end

    # Make sure all of the maintainers were removed from the group
    assert Maintainer.all(:group => @group).empty?, 'Unable to remove all maintainer associations!'

    # Reload the group since we've removed its maintainers
    @group.reload

    # Make sure we were able to delete the group
    assert @group.destroy, 'The group was not deleted!'
    assert Group.get('TEST').nil?, 'The group still exists!'
  end

end
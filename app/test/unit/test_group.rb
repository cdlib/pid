require_relative '../test_helper'

class TestGroup < Minitest::Test
  
  def setup
    Pid.flush!
    @group = Group.create(id: 'TEST', name: 'test_group')

    @pwd = 'secret'
    
    User.create(login: 'testuser', name: 'Test User 1', email: 'test.user@example.org', group: @group, password: @pwd)
    User.create(login: 'testseconduser', name: 'Test User 2', email: 'test.user2@example.org', group: @group, password: @pwd)
    manager = User.create(login: 'testmngr', name: 'Test Manager', email: 'test.mngr@example.org', group: @group, password: @pwd)
    Maintainer.create(user: manager, group: @group)
  end

# ----------------------------------------------------------------------------------------------- 
  def test_create_new
    # Make sure the save function is working
    group = Group.new(id: 'NEW', name: 'New Group', description: 'This is a new group', host: '127.0.0.1')
    assert group.save, 'Unable to create a new group'
    assert_equal 1, Group.where(id: 'NEW').count, "Unable to find the newly created group!"
    
    # Make sure we cannot save a duplicate
    assert_raises(ActiveRecord::RecordInvalid) { Group.create!(id: 'NEW', name: 'New Group', description: 'This is a new group', host: '127.0.0.1') }
  end

# -----------------------------------------------------------------------------------------------  
  def test_modify
    # Make sure we can update the group
    @group.update(name: 'test group modified')
    @group.save

    group = Group.find_by(id: 'TEST')
    assert_equal 'test group modified', group.name, 'The change was not saved!'
  end

# -----------------------------------------------------------------------------------------------  
  def test_users
    group = Group.new(id: 'NEW', name: 'New Group', description: 'This is a new group', host: '127.0.0.1')
    
    # Assert the ability to attach users to a group
    User.create(login: 'newuser', name: 'New User 1', email: 'new.user@example.org', group: group, password: @pwd)

    user2 = User.new(login: 'seconduser', name: 'New User 2', email: 'new2.user@example.org', password: @pwd)
    group.users << user2
    group.save
    
    assert_equal 2, group.users.count, "Unable to add both users to the group!"
  end

# -----------------------------------------------------------------------------------------------  
  def test_maintainers
    current_count = User.count

    group = Group.new(id: 'NEW', name: 'New Group', description: 'This is a new group', host: '127.0.0.1')
    
    # Assert the ability to attach maintainers to a group
    user1 = User.create(login: 'newuser', name: 'New User 1', email: 'new.user@example.org', password: @pwd)
    user2 = User.create(login: 'seconduser', name: 'New User 2', email: 'new2.user@example.org', password: @pwd)

    assert_equal current_count + 2, User.count, "The 2 users were not created."
    
    Maintainer.create(group: group, user: user1)
    Maintainer.create(group: group, user: user2)

    group.reload
    
    assert_equal 2, group.maintainers.count, "Unable to add both maintainers to the group!"
  end

# -----------------------------------------------------------------------------------------------  
  def test_delete
    # Try to delete a group that has members
    assert_raises(ActiveRecord::DeleteRestrictionError) { @group.destroy }
    
    @group.users.clear
    @group.save 

    # Make sure we were able to clear the group's members
    assert_equal 0, @group.users.size, 'Unable to remove all user associations with the group!'
    
    # Try to delete the group when it still has a maintainer
    assert_raises(ActiveRecord::DeleteRestrictionError) { @group.destroy }

    Maintainer.where(group: @group).destroy_all

    # Make sure all of the maintainers were removed from the group
    assert Maintainer.where(group: @group).empty?, 'Unable to remove all maintainer associations!'

    # Reload the group since we've removed its maintainers
    @group.reload

    # Make sure we were able to delete the group
    assert @group.destroy, 'The group was not deleted!'
    assert_nil Group.find_by(id: 'TEST'), 'The group still exists!'
  end

end
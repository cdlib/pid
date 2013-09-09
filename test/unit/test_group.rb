require_relative '../test_helper'

class TestGroup < Test::Unit::TestCase
  def setup
    Pid.flush!
    @group = Group.new(:id => 'TEST', :name => 'test_group')
    @group.save

    User.new(:login => 'test_user', :name => 'Test User 1', :email => 'test.user@example.org', :group => @group).save
    User.new(:login => 'test_user2', :name => 'Test User 2', :email => 'test.user2@example.org', :group => @group).save
    mngr = User.new(:login => 'test_mngr', :name => 'Test Manager', :email => 'test.mngr@example.org', :group => @group)
    mngr.save

    Maintainer.new(:user => mngr, :group => @group).save
  end
    
  def test_create_new
    grp = Group.new(:id => 'NEW', :name => 'New Group', 
                    :description => 'This is a new group', :host => '127.0.0.1')
    
    assert grp.save, 'Unable to create a new group'
  end

  def test_modify
    @group.name = 'test group modified'
    @group.save

    grp = Group.get('TEST')
    assert_equal 'test group modified', grp.name, 'The change was not saved!'
  end

  def test_delete
    assert !@group.destroy, 'Was able to delete a group that still had users associated!'

    @group.users.clear
    @group.save 

    assert_equal 0, @group.users.size, 'Unable to remove all user associations with the group!'

    assert !@group.destroy, 'Was able to delete a group that still had a maintainer associated!'

    Maintainer.all(:group => @group).each do |maintainer|
      maintainer.destroy
    end

    assert Maintainer.all(:group => @group).empty?, 'Unable to remove all maintainer associations!'

    # Reload the group since we've removed its maintainers
    @group.reload

    assert @group.destroy, 'The group was not deleted!'

    assert Group.get('TEST').nil?, 'The group still exists!'
  end

end
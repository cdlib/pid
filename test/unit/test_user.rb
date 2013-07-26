require_relative '../test_helper'

class TestUser < Test::Unit::TestCase
  
    def setup
      Pid.flush!
      @group = Group.new(:id => 'TEST', :name => 'test_group')
      @group.save
    end
    
    def test_create_new
      user = User.new(:login => 'test_user', :name => 'Test User', :email => 'test@example.org')
      user.group = @group
      user.save
      assert_equal User.first.login, 'test_user'
    end
    
    def test_modify
      user = User.new(:login => 'test_user', :name => 'Test User', :email => 'test@example.org')
      user.group = @group
      user.save
      assert_equal User.first.name, 'Test User'
      user.name = 'New Name'
      user.save
      assert_equal User.first.name, 'New Name'
    end
    
    def test_active_and_deactivated_users
      user1 = User.new(:login => 'test_user1', :name => 'Test User1', :email => 'test@example.org')
      user1.group = @group
      user1.save
      user2 = User.new(:login => 'test_user2', :name => 'Test User2', :email => 'test2@example.org')
      user2.group = @group
      user2.save
      assert_equal User.active.count, 2
      assert_equal User.deactivated.count, 0
      user1.active = false
      user1.save
      assert_equal user1.active?, false
      assert_equal User.active.count, 1
      assert_equal User.deactivated.count, 1
    end
    
end
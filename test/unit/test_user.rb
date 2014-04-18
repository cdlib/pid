require_relative '../test_helper'

class TestUser < Minitest::Test
  
  def setup
    Pid.flush!
    @group = Group.new(:id => 'TEST', :name => 'test_group')
    @group.save
    
    @pwd = 'password'
    
    @user = User.new(:login => 'test_user', :name => 'Test', :email => 'test@example.org', :group => @group, :password => @pwd)
    @user.save
  end
    
# -----------------------------------------------------------------------------------------------     
  def test_create_new
    # Make sure we can save a new user
    assert !User.first(:login => @user.login).nil?, "Unable to create a user"
    
    # Make sure the password was encrypted and a salt was created
    assert User.first(:login => @user.login).hashed_password != @pwd, "Password was not encrypted. It was stored as clear text!"
    assert !User.first(:login => @user.login).salt.nil?, "No password salt was generated!"
    
    # Make sure we cannot save a duplicate Login Id
    assert_raises(DataMapper::SaveFailureError){ User.new(:login => @user.login, :name => 'Test', :email => 'test@example.org', :password => @pwd).save }
    
    # Make sure we cannot save a User without a login
    assert_raises(DataMapper::SaveFailureError){ User.new(:name => 'Test User', :email => 'test@example.org', :password => @pwd).save }
    
    # Make sure we cannot save a User without a name
    assert_raises(DataMapper::SaveFailureError){ User.new(:login => 'new_user', :email => 'test@example.org', :password => @pwd).save }
    
    # Make sure we cannot save a User without an email
    assert_raises(DataMapper::SaveFailureError){ User.new(:login => 'new_user', :name => 'Test User', :password => @pwd).save }
    
    # Make sure we cannot save a User with an invalid email
    assert_raises(DataMapper::SaveFailureError){ User.new(:login => 'new_user', :name => 'Test User', :email => 'test', :password => @pwd).save }
  end
  
# -----------------------------------------------------------------------------------------------   
  def test_modify
    user = User.new(:login => 'new_user', :name => 'New', :email => 'new@example.org', :group => @group, :password => @pwd)
    user.save
    
    # Make sure we can modify a user record
    user.name = 'New Name'
    user.save
    assert_equal User.first(:login => 'new_user').name, 'New Name'
    
    # Make sure we cannot save a duplicate Login Id
    user.login = "test_user"
    assert_raises(DataMapper::SaveFailureError){ user.save }
    
    # Make sure we cannot save a User without a login
    user.login = ""
    assert_raises(DataMapper::SaveFailureError){ user.save }
    user.login = "new_user"
    
    # Make sure we cannot save a User without a name
    user.name = ""
    assert_raises(DataMapper::SaveFailureError){ user.save }
    user.name = "New Name"
    
    # Make sure we cannot save a User without an email
    user.email = ""
    assert_raises(DataMapper::SaveFailureError){ user.save }
    
    # Make sure we cannot save a User with an invalid email
    user.email = "new"
    assert_raises(DataMapper::SaveFailureError){ user.save }
    
  end
  
# -----------------------------------------------------------------------------------------------   
  def test_authenticate
    # Make sure we can authenticate
    assert !User.authenticate(@user.login, @pwd).nil?, "Unable to authenticate!"
    
    # Make sure authentication fails with bad login
    assert User.authenticate('new_user', @pwd).nil?, "Able to authenticate as non-existent user!"
    
    # Make sure authentication fails with bad password
    assert User.authenticate(@user, 'badpassword').nil?, "Able to authenticate with a bad password!"
    
    # Make sure authentication fails with bad login id and bad password
    assert User.authenticate(@user, 'badpassword').nil?, "Able to authenticate with a bad password!"
  end
  
# -----------------------------------------------------------------------------------------------   
  def test_encrypt_password
    assert @pwd != User.encrypt(@pwd, @user.salt), "Unable to encrypt the password!"
  end

# -----------------------------------------------------------------------------------------------     
  def test_reset_password
    @user.reset_password
    @user.save
    @user.reload
    
    assert !@user.reset_code.nil?, "The reset command did not set the reset code and timer!"
  end
  
# -----------------------------------------------------------------------------------------------   
  def test_active_and_deactivated_users
    user = User.new(:login => 'new_user', :name => 'New', :email => 'new@example.org', :group => @group, :password => @pwd)
    user.save
    
    # Make sure the active check succeeds
    assert user.active?, "The user was not active!"
    
    # Make sure there are 2 active users
    assert_equal User.active.count, 2, "Did not find 2 active users!"
    
    user.active = false
    user.save
    
    #Make sure the active check fails
    assert !user.active?, "The user is still active!"
    
    # Make sure there is 1 active user and 1 inactive user
    assert_equal User.active.count, 1
    assert_equal User.deactivated.count, 1
  end
  
# -----------------------------------------------------------------------------------------------   
  def test_random_string
    assert User.random_string(10) != User.random_string(10), "The User object did not generate separate random strings!"
  end
    
end
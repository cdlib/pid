require_relative '../test_helper'

class TestUser < Minitest::Test

  def setup
    Pid.flush!
    @group = Group.create(id: 'TEST', name: 'test_group')

    @pwd = 'password'

    @user = User.create(login: 'testuser', name: 'Test', email: 'test@example.org', group: @group, password: @pwd)
  end
    
# -----------------------------------------------------------------------------------------------     
  def test_create_new
    # Make sure we can save a new user
    assert User.find_by(login: @user.login), "Unable to create a user"

    # Make sure the password was encrypted and a salt was created
    user = User.find_by(login: @user.login)
    assert user.hashed_password != @pwd, "Password was not encrypted. It was stored as clear text!"
    assert user.salt, "No password salt was generated!"

    # Make sure we cannot save a duplicate Login Id
    assert_raises(ActiveRecord::RecordInvalid) { User.create!(login: @user.login, name: 'Test', email: 'test@example.org', password: @pwd) }

    # Make sure we cannot save a User without a login
    assert_raises(ActiveRecord::RecordInvalid) { User.create!(name: 'TestUser', email: 'test@example.org', password: @pwd) }

    # Make sure we cannot save a User without a name
    assert_raises(ActiveRecord::RecordInvalid) { User.create!(login: 'newuser', email: 'test@example.org', password: @pwd) }

    # Make sure we cannot save a User without an email
    assert_raises(ActiveRecord::RecordInvalid) { User.create!(login: 'newuser', name: 'Test User', password: @pwd) }

    # Make sure we cannot save a User with an invalid email
    assert_raises(ActiveRecord::RecordInvalid) { User.create!(login: 'newuser', name: 'Test User', email: 'test', password: @pwd) }
  end
  
# -----------------------------------------------------------------------------------------------   
  def test_modify
    user = User.create(login: 'newuser', name: 'New', email: 'new@example.org', group: @group, password: @pwd)

    # Make sure we can modify a user record
    user.name = 'New Name'
    user.save
    assert_equal User.find_by(login: 'newuser').name, 'New Name'

    # Make sure we cannot save a duplicate Login Id
    user.login = 'testuser'
    assert_raises(ActiveRecord::RecordInvalid) { user.save! }

    # Make sure we cannot save a User without a login
    user.login = ''
    assert_raises(ActiveRecord::RecordInvalid) { user.save! }

    user.login = 'newuser'

    # Make sure we cannot save a User without a name
    user.name = ''
    assert_raises(ActiveRecord::RecordInvalid) { user.save! }

    user.name = 'New Name'

    # Make sure we cannot save a User without an email
    user.email = ''
    assert_raises(ActiveRecord::RecordInvalid) { user.save! }

    # Make sure we cannot save a User with an invalid email
    user.email = 'new'
    assert_raises(ActiveRecord::RecordInvalid) { user.save! }
  end

# -----------------------------------------------------------------------------------------------   
  def test_authenticate
    # Make sure we can authenticate
    assert User.authenticate(@user.login, @pwd), "Unable to authenticate!"

    # Make sure authentication fails with a bad login
    assert_nil User.authenticate('nonexistent', @pwd), "Able to authenticate as a non-existent user!"

    # Make sure authentication fails with a bad password
    assert_nil User.authenticate(@user.login, 'badpassword'), "Able to authenticate with a bad password!"

    # Make sure authentication fails with a bad login id and bad password
    assert_nil User.authenticate('nonexistent', 'badpassword'), "Able to authenticate with bad login and password!"
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
    
    assert @user.reset_code, "The reset command did not set the reset code and timer!"
  end
  
# -----------------------------------------------------------------------------------------------   
  def test_active_and_deactivated_users
    user = User.create(login: 'newuser', name: 'New', email: 'new@example.org', group: @group, password: @pwd)

    # Make sure the active check succeeds
    assert user.active?, "The user was not active!"

    # Make sure there are 2 active users
    assert_equal User.active.count, 2, "Did not find 2 active users!"

    user.active = false
    user.save

    # Make sure the active check fails
    refute user.active?, "The user is still active!"

    # Make sure there is 1 active user and 1 inactive user
    assert_equal User.active.count, 1
    assert_equal User.deactivated.count, 1
  end
  
# -----------------------------------------------------------------------------------------------   
  def test_random_string
    refute_equal User.random_string(10), User.random_string(10), "The User object did not generate separate random strings!"
  end
    
end
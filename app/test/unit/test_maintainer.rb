require_relative '../test_helper'

class TestMaintainer < Minitest::Test

  def setup
    Pid.flush!
    @group = Group.create(id: 'TEST', name: 'test_group')
    
    @user = User.create(login: 'testuser', name: 'Test User 1', email: 'test.user@example.org', group: @group, password: 'secret')
    @manager = User.create(login: 'testmngr', name: 'Test Manager', email: 'test.mngr@example.org', group: @group, password: 'secret')

    Maintainer.create(user: @manager, group: @group)
  end

  def test_create_new
    maintainer = Maintainer.new(user: @user, group: @group)

    assert maintainer.save, 'Unable to create a new maintainer association!'
  end

  def test_delete
    maintainer = Maintainer.find_by(group: @group)

    assert maintainer.destroy, 'Was unable to delete a maintainer relationship!'
    assert Maintainer.find_by(group: @group).nil?, 'The maintainer relationship still exists!'
  end
  
end
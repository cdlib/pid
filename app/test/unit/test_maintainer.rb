require_relative '../test_helper'

class TestMaintainer < Minitest::Test
  def setup
    Pid.flush!
    @group = Group.new(:id => 'TEST', :name => 'test_group')
    @group.save

    @user = User.new(:login => 'test_user', :name => 'Test User 1', :email => 'test.user@example.org', :group => @group, :password => 'secret')
    @mngr = User.new(:login => 'test_mngr', :name => 'Test Manager', :email => 'test.mngr@example.org', :group => @group, :password => 'secret')
    @mngr.save
    @user.save

    Maintainer.new(:user => @mngr, :group => @group).save
  end
    
  def test_create_new
    mntr = Maintainer.new(:user => @user, :group => @group)
    
    assert mntr.save, 'Unable to create a new maintainer association!'
  end

  def test_delete
    mntr = Maintainer.first(:group => @group)
    assert mntr.destroy, 'Was unable to delete a maintainer relationship!'

    assert Maintainer.first(:group => @group).nil?, 'The maintainer relatinship still exists!'
  end

end
require_relative '../test_helper'

class TestSkipCheck < Test::Unit::TestCase
  def setup
    Pid.flush!
    @group = Group.new(:id => 'TEST', :name => 'test_group')
    @group.save
  end
    
  def test_create_new
    chk = SkipCheck.new(:domain => 'www.yahoo.com', :created_at => Time.now, :group => @group.id)
    
    assert chk.save, 'Unable to create a new skip check!'
  end

  def test_delete
    chk = SkipCheck.new(:domain => 'www.yahoo.com', :created_at => Time.now, :group => @group.id)
    chk.save

    assert chk.destroy, 'Was unable to delete the skip check!'
  end

end
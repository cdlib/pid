require_relative '../test_helper'

class TestSkipCheck < Test::Unit::TestCase
  def setup
    Pid.flush!
    @group = Group.new(:id => 'TEST', :name => 'test_group')
    @group.save
  end
    
# ----------------------------------------------------------------------------------------------- 
  def test_create_new
    # Make sure we can save a record
    chk = SkipCheck.new(:domain => 'www.yahoo.com', :created_at => Time.now, :group => @group.id)
    assert chk.save, 'Unable to create a new skip check!'
    
    # Make sure we cannot save a duplicate domain
    assert_raise(DataObjects::IntegrityError){ SkipCheck.new(:domain => 'www.yahoo.com', :created_at => Time.now, :group => @group.id).save }
  end

# ----------------------------------------------------------------------------------------------- 
  def test_delete
    chk = SkipCheck.new(:domain => 'www.yahoo.com', :created_at => Time.now, :group => @group.id)
    chk.save
    assert chk.destroy, 'Was unable to delete the skip check!'
  end

end
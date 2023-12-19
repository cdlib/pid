require_relative '../test_helper'

class TestSkipCheck < Minitest::Test

  def setup
    Pid.flush!
    @group = Group.create(id: 'TEST', name: 'test_group')
  end
    
# ----------------------------------------------------------------------------------------------- 
  def test_create_new
    # Make sure we can save a record
    check = SkipCheck.new(domain: 'www.yahoo.com', created_at: Time.now, group: @group.id)

    assert check.save, 'Unable to create a new skip check!'

    # Make sure we cannot save a duplicate domain
    assert_raises(ActiveRecord::RecordInvalid) { SkipCheck.create!(domain: 'www.yahoo.com', created_at: Time.now, group: @group.id) }
  end

# ----------------------------------------------------------------------------------------------- 
  def test_delete
    check = SkipCheck.create(domain: 'www.yahoo.com', created_at: Time.now, group: @group.id)
    
    assert check.destroy, 'Was unable to delete the skip check!'
  end
  
end
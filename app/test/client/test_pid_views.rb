require_relative '../test_helper'

class PidClientTestApp < Minitest::Test
  include Rack::Test::Methods
  include Capybara::DSL
  
  Capybara.app = PidApp.new
  
  def app
    PidApp
  end
  
  def setup
    Pid.flush!
    User.flush!
    Group.flush!
    Maintainer.flush!
    @pwd = 'secret'
    @group = Group.new(:id => 'TEST', :name => 'test_group')
    @group2 = Group.new(:id => 'TEST2', :name => 'test_group')
    @group2.save
    
    @user = User.new(:login => 'test_user', :name => 'Test User', :password => @pwd, 
                      :email => 'test@example.org')
    @mgr = User.new(:login => 'test_mgr', :name => 'Test Manager', :password => @pwd, 
                      :email => 'mgr@example.org')
    @adm = User.new(:login => 'test_adm', :name => 'Test Admin', :password => @pwd, 
                      :email => 'adm@example.org', :super => true, :group => @group2)
    @group.users << @user
    @group.users << @mgr
    @group.save
    
    Maintainer.new(:group => @group, :user => @mgr).save
    Maintainer.new(:group => @group2, :user => @mgr).save
    
    Pid.mint(:url => 'http://www.testme.abc', :username => @user.login, :change_category => 'User_Entered', :group => @group)
    Pid.mint(:url => 'http://maps.testme.abc', :username => @mgr.login, :change_category => 'User_Entered', :group => @group)
    Pid.mint(:url => 'http://test.cdlib.abc', :username => @user.login, :change_category => 'User_Entered', :group => @group)
    Pid.mint(:url => 'http://www.testit.abc', :username => @user.login, :change_category => 'User_Entered', :group => @group)
    Pid.mint(:url => 'http://www.testgroup2.abc', :username => @adm.login, :change_category => 'User_Entered', :group => @group2)
  end
  
  def teardown
    Capybara.reset_sessions!
  end
  
# --------------------------------------------------------------------------------------------------------
# Search page tests - performed client side because results come back as json and the results table is built client side
# --------------------------------------------------------------------------------------------------------
  def test_post_search
    login(@user.login, @pwd)
    
    # Warning, any tests to count the number of <tr> returned should account for the <th> row!
    
    visit '/link/search'
    
    # wilcard match 1 urls
    fill_in 'url', with: 'test.cdlib.abc'
    # select @mgr.id, from: 'userid' 
    click_button 'submit'
    
    trs = page.all("tr")
    assert_equal 2, trs.size, "Expected 1 result but found #{trs.size - 1} on URL search for test.cdlib.abc"
    
    # wilcard match 2 urls
    fill_in 'url', with: 'testme.abc'
    click_button 'submit'
    
    trs = page.all("tr")
    assert_equal 3, trs.size, "Expected 2 results but found #{trs.size - 1} on URL search for testme.abc"

    # wilcard match ALL url should fail becuase not enough criteria
    fill_in 'url', with: '.abc'
    click_button 'submit'
    
    trs = page.all("tr")
    assert_equal 1, trs.size, "Expected 0 results but found #{trs.size - 1} on URL search for .abc"
    fill_in 'url', with: ''
    
    # wilcard match ALL url should fail becuase not enough criteria
    fill_in 'url', with: 'http://'
    click_button 'submit'
    
    trs = page.all("tr")
    assert_equal 6, trs.size, "Expected 5 results but found #{trs.size - 1} on URL search for http://"
    fill_in 'url', with: ''
      
    # Search for PID ranges
    fill_in 'pid_low', with: '2'
    fill_in 'pid_high', with: '3'
    click_button 'submit'
    
    trs = page.all("tr")
    assert_equal 3, trs.size, "Expected 2 results but found #{trs.size - 1} on PID Range search"
    fill_in 'pid_low', with: ''
    fill_in 'pid_high', with: ''
    
    # Search for users
    select @mgr.name, :from => 'userid'
    click_button 'submit'
    
    trs = page.all("tr")
    assert_equal 2, trs.size, "Expected 1 result but found #{trs.size - 1} on specific user search"
    select '', :from => 'userid'
    
    # Search for date ranges
    Pid.first(:url => 'http://www.testme.abc').revise(:modified_at => '2013-09-01 13:30:00', :is_seed => true, :group => @group)
    assert Pid.first(:url => 'http://www.testme.abc').modified_at = '2013-09-01 13:30:00', "The modified date was not saved!"
    
    fill_in 'modified_low', :with => '2013-08-30'
    fill_in 'modified_high', :with => '2013-09-10'
    click_button 'submit'
    
    trs = page.all("tr")
    assert_equal 2, trs.size, "Expected 1 result but found #{trs.size - 1} on modified date range search #{page.body}"
    fill_in 'modified_low', :with => ''
    fill_in 'modified_high', :with => ''
    
    # Search for inactive
    Pid.first(:url => 'http://test.cdlib.abc').revise(:dead_pid_url => 'http://www.google.com', :deactivated => true, :group => @group)
    select "No", :from => 'active'
    fill_in 'url', with: 'http://'
    click_button 'submit'
    
    trs = page.all("tr")
    assert_equal 2, trs.size, "Expected 1 result but found #{trs.size - 1} on search for inactive pids"
    select '', :from => 'active'
    
    visit '/user/logout'
  end
  
  def test_search_pid_auto_populate
    login(@user.login, @pwd)
    
    visit '/link/search'
    
    fill_in 'pid_low', with: '2'
    assert_equal '2', page.find('#pid_high').value, "The High Value of the PID range did not default to the value entered in the Low Value!"
    
    fill_in 'pid_high', with: '70'
    fill_in 'pid_low', with: '4'
    assert_equal '70', page.find('#pid_high').value, "The High Value of the PID range was overwritten by the value entered in the Low Value!"
  end

  
# --------------------------------------------------------------------------------------------------------
# Helper methods 
# --------------------------------------------------------------------------------------------------------  
private
  def login(userid, password)
    visit '/user/login'
  
    fill_in 'login', with: userid
    fill_in 'password', with: password
    click_button 'submit'
  end
    
end
require_relative '../test_helper'

class PidClientTestApp < Minitest::Test
  include Rack::Test::Methods
  include Capybara::DSL
  
  # Capybara.app = PidApp
  
  # def app
  #   PidApp
  # end
  
  def setup
    Pid.flush!
    User.flush!
    Group.flush!
    Maintainer.flush!
    
    @pwd = 'secret'
    @group = Group.new(id: 'TEST', name: 'test_group')
    @group2 = Group.create(id: 'SECONDTEST', name: 'test_group')
    
    @user = User.new(login: 'testuser', name: 'Test User', password: @pwd, email: 'test@example.org')
    @mgr = User.new(login: 'testmgr', name: 'Test Manager', password: @pwd, email: 'mgr@example.org')
    @adm = User.new(login: 'testadm', name: 'Test Admin', password: @pwd, email: 'adm@example.org', super: true, group: @group2)
    @group.users << @user
    @group.users << @mgr
    @group.save
    
    Maintainer.create(group: @group, user: @mgr)
    Maintainer.create(group: @group2, user: @mgr)
    
    Pid.mint(url: 'http://www.testme.abc', username: @user.login, change_category: 'User_Entered', group: @group)
    Pid.mint(url: 'http://maps.testme.abc', username: @mgr.login, change_category: 'User_Entered', group: @group)
    Pid.mint(url: 'http://test.cdlib.abc', username: @user.login, change_category: 'User_Entered', group: @group)
    Pid.mint(url: 'http://www.testit.abc', username: @user.login, change_category: 'User_Entered', group: @group)
    Pid.mint(url: 'http://www.testgroup2.abc', username: @adm.login, change_category: 'User_Entered', group: @group2)
  end
  
  def teardown
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end
  
# --------------------------------------------------------------------------------------------------------
# Search page tests - performed client side because results come back as json and the results table is built client side
# --------------------------------------------------------------------------------------------------------
  def test_get_search
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

    # wilcard match 5 urls
    fill_in 'url', with: '.abc'
    click_button 'submit'
    
    trs = page.all("tr")
    assert_equal 6, trs.size, "Expected 5 results but found #{trs.size - 1} on URL search for .abc"
    fill_in 'url', with: ''
    
    # wilcard match 5 urls
    fill_in 'url', with: 'http://'
    click_button 'submit'
    
    trs = page.all("tr")
    assert_equal 6, trs.size, "Expected 5 results but found #{trs.size - 1} on URL search for http://"
    fill_in 'url', with: ''

    # Search for PID ranges
    fill_in 'pid_low', with: '2'
    execute_script("$('#pid_low').trigger('input');")
    fill_in 'pid_high', with: '3'
    execute_script("$('#pid_high').trigger('input');")
    click_button 'submit'
    
    trs = page.all("tr")
    assert_equal 3, trs.size, "Expected 2 results but found #{trs.size - 1} on PID Range search"

    fill_in 'pid_low', with: ''
    execute_script("$('#pid_low').trigger('input');")
    fill_in 'pid_high', with: ''
    execute_script("$('#pid_high').trigger('input');")
    
    # Search for users
    select @mgr.login, from: 'userid'
    click_button 'submit'
    
    trs = page.all("tr")
    assert_equal 2, trs.size, "Expected 1 result but found #{trs.size - 1} on specific user search" + page.body
    select '', from: 'userid'
    
    # Search for date ranges
    Pid.find_by(url: 'http://www.testme.abc').revise(modified_at: '2013-09-01 13:30:00', is_seed: true, group: @group)
    assert_equal Pid.find_by(url: 'http://www.testme.abc').modified_at, '2013-09-01 13:30:00', "The modified date was not saved!"

    # fill_in 'modified_low', with: '2013-08-30'
    # fill_in 'modified_high', with: '2013-09-10'
    fill_in 'modified_low', with: '08/30/2013'
    execute_script("$('#modified_low').trigger('input');")
    fill_in 'modified_high', with: '09/10/2013'
    execute_script("$('#modified_high').trigger('input');")
    click_button 'submit'
    
    trs = page.all("tr")
    assert_equal 2, trs.size, "Expected 1 result but found #{trs.size - 1} on modified date range search"
    fill_in 'modified_low', with: ''
    execute_script("$('#modified_low').trigger('input');")
    fill_in 'modified_high', with: ''
    execute_script("$('#modified_high').trigger('input');")
    
    # Search for inactive
    Pid.find_by(url: 'http://test.cdlib.abc').revise(dead_pid_url: 'http://www.google.com', deactivated: true, group: @group)
    select 'No', from: 'active'
    fill_in 'url', with: 'http://'
    click_button 'submit'
    
    trs = page.all("tr")
    assert_equal 2, trs.size, "Expected 1 result but found #{trs.size - 1} on search for inactive pids"
    select '', from: 'active'
    
    visit '/user/logout'
  end
  
  def test_search_pid_contraints
    login(@user.login, @pwd)
    
    visit '/link/search'
    
    fill_in 'pid_low', with: '2'
    execute_script("$('#pid_low').trigger('input');")
    click_button 'submit'

    trs = page.all("tr")
    assert_equal 0, trs.size, "Expected 0 results because submisison should've been prevented by required field, but found some on PID Range search"
    fill_in 'pid_low', with: ''
    execute_script("$('#pid_low').trigger('input');")

    fill_in 'pid_high', with: '3'
    execute_script("$('#pid_high').trigger('input');")
    click_button 'submit'

    trs = page.all("tr")
    assert_equal 0, trs.size, "Expected 0 results because submisison should've been prevented by required field, but found some on PID Range search"
    fill_in 'pid_high', with: ''
    execute_script("$('#pid_high').trigger('input');")

    fill_in 'pid_low', with: '2'
    execute_script("$('#pid_low').trigger('input');")
    fill_in 'pid_high', with: '3'
    execute_script("$('#pid_high').trigger('input');")
    click_button 'submit'
    
    trs = page.all("tr")
    assert_equal 3, trs.size, "Expected 2 results but found #{trs.size - 1} on PID Range search"
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
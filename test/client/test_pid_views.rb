require_relative '../test_helper'

class PidClientTestApp < Test::Unit::TestCase
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
    @group = Group.new(:id => 'UCLA', :name => 'test_group')
    @user = User.new(:login => 'test_user', :name => 'Test User', :password => @pwd, 
                      :email => 'test@example.org')
    @mgr = User.new(:login => 'test_mgr', :name => 'Test Manager', :password => @pwd, 
                      :email => 'mgr@example.org')
    @adm = User.new(:login => 'test_adm', :name => 'Test Admin', :password => @pwd, 
                      :email => 'adm@example.org', :super => true)
    @group.users << @user
    @group.users << @mgr
    @group.save
    
    Maintainer.new(:group => @group, :user => @mgr).save
    
    Pid.mint(:url => 'http://www.testme.abc', :username => @user.login, :change_category => 'User_Entered', :group => @group)
    Pid.mint(:url => 'http://maps.testme.abc', :username => @mgr.login, :change_category => 'User_Entered', :group => @group)
    Pid.mint(:url => 'http://test.cdlib.abc', :username => @user.login, :change_category => 'User_Entered', :group => @group)
    Pid.mint(:url => 'http://www.testit.abc', :username => @user.login, :change_category => 'User_Entered', :group => @group)
  end
  
  def teardown
    Capybara.reset_sessions!
  end
  
# --------------------------------------------------------------------------------------------------------
# Search page tests
# --------------------------------------------------------------------------------------------------------
  def test_search_load
    login(@user.login, @pwd)
    
    visit '/link/search'
    
    assert page.has_selector?('#url'), 'No URL criteria found!'
    assert page.has_selector?('#pid_low'), 'No pid range criteria found!'
    assert page.has_selector?('#modified_high'), 'No modified date range criteria found!'
  end
  
  def test_post_search
    login(@user.login, @pwd)
    
    # Warning, any tests to count the number of <tr> returned should account for the <th> row!
    
    visit '/link/search'
    
  # wilcard match 1 urls
    fill_in 'url', with: 'test.cdlib.abc'
#    select @mgr.id, from: 'userid' 
    click_button 'submit'
    
#puts page.html    
    
    trs = page.all("tr")
    assert_equal 2, trs.size, "Expected 1 results but found #{trs.size - 1}"
    
  # wilcard match 2 urls
    fill_in 'url', with: 'testme.abc'
    click_button 'submit'
    
    trs = page.all("tr")
    assert_equal 3, trs.size, "Expected 2 results but found #{trs.size - 1}"

  # wilcard match ALL urls
    fill_in 'url', with: '.abc'
    click_button 'submit'
    
    trs = page.all("tr")
    assert_equal 5, trs.size, "Expected 4 results but found #{trs.size - 1}"
    
    # Search for PID ranges
    # Search for users
    # Search for date ranges
    # Search for change categories
    
    # Search as Maintainer of multiple groups and as super admin
  end
  
=begin
  def test_post_search_record_limit
    login(@user.login, @pwd)
    
    # ensure that a search with over 100 hits returns only 100 PIDs
    urls = *(1..(APP_CONFIG['search_results_limit'] + 1))
    urls.each do |url| 
      Pid.mint(:url => 'http://www.testwikipedia.org/#{url}', :username => @user.login, :change_category => 'User_Entered', :group => @group)
    end
    
    visit '/link/search'
    
  # wilcard match 1 urls
    fill_in 'url', with: 'testwikipedia.org/'
#    select @mgr.id, from: 'userid' 
    click_button 'submit'
   
    trs = page.all("tr")
    assert_equal (APP_CONFIG['search_results_limit'].to_i + 1), trs.size, "Expected #{APP_CONFIG['search_results_limit']} results but found #{trs.size - 1}"
  end
=end
  
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
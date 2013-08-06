require_relative '../test_helper'

class PidClientTestApp < Test::Unit::TestCase
  include Rack::Test::Methods
  include Capybara::DSL
  
  Capybara.app = PidApp.new
  MESSAGE_CONFIG = YAML.load_file('conf/message.yml')
  HTML_CONFIG = YAML.load_file('conf/html.yml')
  APP_CONFIG = YAML.load_file('conf/app.yml')
  
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
    Pid.mint(:url => 'http://maps.testme.abc', :username => @user.login, :change_category => 'User_Entered', :group => @group)
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
  
=begin
  def test_search_max_results
    urls = *(1..APP_CONFIG['search_results_limit'].to_i)
    urls.each{ |url| Pid.mint(:url => 'http://www.testwikipedia.org/#{url}', :username => @user.login, :change_category => 'User_Entered', :group => @group)}
    
puts "Max search results = #{APP_CONFIG['search_results_limit'].to_i}"
    
    login(@user.login, @pwd)
    
    visit '/link/search'

puts "Clicking button on #{Time.now}"

    #click_button 'submit'
    find_button("submit").click()
    
puts "moved to next command on #{Time.now}"
    
    assert_equal (APP_CONFIG['search_results_limit'].to_i + 1), last_response.body.gsub('<tr>').count, "Expected #{APP_CONFIG['search_results_limit'].to_i} PIDs but got #{last_response.body.gsub('<tr>').count - 1}"
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
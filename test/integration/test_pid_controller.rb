require_relative '../test_helper'

class PidManageApp < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    PidApp
  end

  def setup
    Pid.flush!
    @pwd = 'secret' 
    @group = Group.new(:id => 'UCLA', :name => 'test_group')
    @user = User.new(:login => 'test_user', :name => 'Test User', :email => 'test@example.org', :password => @pwd)
    @group.users << @user
    @group.save
    
    post '/user/login', { :login => @user.login, :password => @pwd }
  end
  
# ---------------------------------------------------------------
# Test security
# ---------------------------------------------------------------
  def test_pid_security
    get '/user/logout'
    
    get '/link/search'
    assert last_response.redirect?, 'Was able to access PID search without logging in!'
    assert_equal 'http://example.org/user/login', last_response.location, "Expected to redirect to login page but instead went to #{last_response.location}"
    
    post '/link/search'
    assert last_response.redirect?, 'Was able to process a PID search without logging in!'
    assert_equal 'http://example.org/user/login', last_response.location, "Expected to redirect to login page but instead went to #{last_response.location}"
    
    get '/link/1'
    assert last_response.redirect?, 'Was able to look up a PID without logging in!'
    assert_equal 'http://example.org/user/login', last_response.location, "Expected to redirect to login page but instead went to #{last_response.location}"
    
    post '/link'
    assert last_response.redirect?, 'Was able to create a PID without logging in!'
    assert_equal 'http://example.org/user/login', last_response.location, "Expected to redirect to login page but instead went to #{last_response.location}"
    
    put '/link/1'
    assert last_response.redirect?, 'Was able to update a PID without logging in!'
    assert_equal 'http://example.org/user/login', last_response.location, "Expected to redirect to login page but instead went to #{last_response.location}"
    
    get '/link/new'
    assert last_response.redirect?, 'Was able to access new PID page without logging in!'
    assert_equal 'http://example.org/user/login', last_response.location, "Expected to redirect to login page but instead went to #{last_response.location}"
  end
  
  
# ---------------------------------------------------------------
# Search page tests
# ---------------------------------------------------------------
  def test_post_search_not_found
    post '/user/login', { :login => @user.login, :password => @pwd }
    post '/link/search', {:url => 'blah blah blah', :userid => '', :pid_low => '', :pid_high => '', :created_low => '', 
                          :created_high => '', :modified_low => '', :modified_high => '', :active => ''}
    
    assert last_response.not_found?, 'Search returned records for an invalid url!'
    
    # Search for invalid PID range
    # Search for invalid user
    # Search for invalid date range
    # Search for invalid change category
  end
  

# ---------------------------------------------------------------
# Show PID tests
# ---------------------------------------------------------------
  def test_get_pid
    post '/user/login', { :login => @user.login, :password => @pwd }
    
    link = Pid.mint(:url => 'http://cdlib.org', :username => @user.login, :change_category => 'User_Entered', :group => @group)
    get '/link/1'
    assert last_response.ok?, 'Did not find the specified PID'
  end
   
  def test_get_pid_not_found
    post '/user/login', { :login => @user.login, :password => @pwd }
    
    link = Pid.mint(:url => 'http://cdlib.org', :username => @user.login, :change_category => 'User_Entered', :group => @group)
    get '/link/1234'
    assert last_response.not_found?, "Found the specified PID. status: #{last_response.status}"
  end
  
# ---------------------------------------------------------------
# Mint PID tests
# ---------------------------------------------------------------
  def test_get_new_pid
    post '/user/login', { :login => @user.login, :password => @pwd }
    
    get '/link/new'
    assert last_response.ok?, 'Unable to load the new PID screen!'
  end
  
  def test_post_pid
    post '/user/login', { :login => @user.login, :password => @pwd }
    
    post '/link', { :new_urls => 'http://cdlib.org' }
    assert last_response.redirect?, "Failure minting a new PID. status: #{last_response.status}"  #302 = success according to PURL standard
    assert_equal 'http://cdlib.org', Pid.get(1).url, 'PID 1 was not the url we were expecting!'
  end
  
  def test_post_multiple_pids
    post '/user/login', { :login => @user.login, :password => @pwd }
    
    post '/link', { :new_urls => "http://cdlib.org\nhttp://google.com" }
    
    assert last_response.redirect?, "Failure minting new PIDs. status: #{last_response.status}"  #302 = success according to PURL standard
    assert_equal 'http://cdlib.org', Pid.get(1).url, 'PID 1 was not the url we were expecting!'
    assert_equal 'http://google.com', Pid.get(2).url, 'PID 2 was not the url we were expecting!'
  end
  
  def test_post_pid_failure
    post '/user/login', { :login => @user.login, :password => @pwd }
    
    post '/link', { :new_urls => 'cdlib.org' }
    assert_equal 400, last_response.status, "Should have failed with a 400 but we received a status: #{last_response.status}"
  end
  
  def test_post_multiple_pids_success_and_failure
    post '/user/login', { :login => @user.login, :password => @pwd }
    
    post '/link', { :new_urls => "cdlib.org\nhttp://google.com\nblah blah blah\n\nhttp://www.yahoo.com" }
    
    #Since some failed we should get a 400 back, but should be able to find the ones that succeeded
    assert_equal 400, last_response.status, "Should have failed with a 400 but we received a status: #{last_response.status}"
    assert_equal 'http://google.com', Pid.get(1).url, 'PID 1 was not the url we were expecting!'
    assert_equal 'http://www.yahoo.com', Pid.get(2).url, 'PID 2 was not the url we were expecting!'
  end
  
  
# ---------------------------------------------------------------
# Revise PID tests
# ---------------------------------------------------------------
  def test_put_pid
    original = Pid.mint(:url => 'http://testing.cdlib.org/edit', :username => @user.login, :change_category => 'User_Entered', :group => @group)
    assert_equal 'http://testing.cdlib.org/edit', original.url, 'Unable to mint PID!'

    put "/link/#{original.id}", {:url => "http://testing.cdlib.org/news", :active => "on", :group => @group.id}
    assert last_response.ok?, "Unable to update the PID, status: #{last_response.status}"
    
    #reload the pid to make sure the save worked
    changed = Pid.first(:id == original.id)
    assert_equal  "http://testing.cdlib.org/news", changed.url, 'The PID does not have the new URL!'
    assert_not_equal original.url, changed.url, 'The PIDs url matches the original url!'
  end
  
  def test_deactivate_pid
    original = Pid.mint(:url => 'http://testing.cdlib.org/active/pid', :username => @user.login, :change_category => 'User_Entered', :group => @group)
    assert_equal 'http://testing.cdlib.org/active/pid', original.url, 'Unable to mint PID!'
    
    put "/link/#{original.id}", {:url => "Google Search", :active => "", :group => @group.id}
    assert last_response.ok?, "Was unable to deactivate the PID! status: #{last_response.status}"
  end
  
  def test_put_pid_failure
    original = Pid.mint(:url => 'http://testing.cdlib.org/edit/bad', :username => @user.login, :change_category => 'User_Entered', :group => @group)
    assert_equal 'http://testing.cdlib.org/edit/bad', original.url, 'Unable to mint PID!'
    
    # Bad url
    put "/link/#{original.id}", {:url => "Google Search", :active => "on", :group => @group.id}
    
    changed = Pid.first(:id == original.id)
    assert_equal  "http://testing.cdlib.org/edit/bad", changed.url, 'The PIDs url does not match the original url!'
  end
  
  def test_put_pid_not_found
    put "/link/999999", {:url => "http://testing.cdlib.org/edit/404", :active => "on", :group => @group.id}
    assert last_response.not_found?, 'We were able to find a non-existent PID!'
  end
  
end
require_relative '../test_helper'
require 'rexml/document'
require 'open-uri'
require 'nokogiri'
require 'json'

class TestPidController < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    PidApp
  end

  def setup
    Pid.flush!
    User.flush!
    Group.flush!
    Maintainer.flush!
    
    @pwd = 'secret'
    
    @group = Group.new(:id => 'UCSP', :name => 'test_group')
    @group2 = Group.new(:id => 'UCLA', :name => 'test_group2')
    @adm_grp = Group.new(:id => 'ADM', :name => 'test_admin_group')
    @adm = User.new(:login => 'test_admin', :name => 'Test Administrator', :password => @pwd, :email => 'purl-test-admin@cdlib.org', :super => true, 
                    :group => @adm_grp)
    @user = User.new(:login => 'test_user', :name => 'Test User', :password => @pwd, :email => 'purl-test-user@cdlib.org')
    @user2 = User.new(:login => 'test_user2', :name => 'Test User 2', :password => @pwd, :email => 'purl-test-user2@cdlib.org')
    @mgr = User.new(:login => 'test_mgr', :name => 'Test Manager', :password => @pwd, :email => 'purl-test-mgr@cdlib.org')
    
    @group.users << @user
    @group.users << @mgr
    @group.save
    
    @group2.users << @user2
    @group2.save
    
    @adm_grp.users << @adm
    @adm_grp.save
    
    Maintainer.new(:group => @group, :user => @mgr).save
    Maintainer.new(:group => @group2, :user => @mgr).save
    
    Pid.mint(:url => 'http://cdlib.org', :username => @user2.login, :change_category => 'Test', :group => @group2)
    Pid.mint(:url => 'http://www.google.com', :username => @user.login, :change_category => 'Test', :group => @group)
    Pid.mint(:url => 'http://www.yahoo.com', :username => @user.login, :change_category => 'Test', :group => @group)
    Pid.mint(:url => 'http://www.huffingtonpost.com', :username => @mgr.login, :change_category => 'Test', :group => @group)
    Pid.mint(:url => 'http://www.dailybeast.com', :username => @adm.login, :change_category => 'Test', :group => @adm_grp)
    Pid.mint(:url => 'http://www.gizmodo.com', :username => @adm.login, :change_category => 'Test', :group => @adm_grp)
    
    Interested.new(:group => @group2, :pid => Pid.first(:url => 'http://www.google.com')).save
  end
  
# -----------------------------------------------------------------------------------------------
  def test_get_main_menu
    security_check_basic("/link", "get", nil)
    check_login_for_each_user_type("/link", PidApp::HTML_CONFIG['header_index'])
  end
    
# -----------------------------------------------------------------------------------------------
  def test_get_search
    security_check_basic("/link/search", "get", nil)
    check_login_for_each_user_type("/link/search", PidApp::HTML_CONFIG['header_search_criteria'])
  end

# -----------------------------------------------------------------------------------------------
  def test_get_new
    security_check_basic("/link/new", "get", nil)
    check_login_for_each_user_type("/link/new", PidApp::HTML_CONFIG['header_pid_register'])
  end
  
# -----------------------------------------------------------------------------------------------
  def test_get_edit
    security_check_basic("/link/edit", "get", nil)
    check_login_for_each_user_type("/link/edit", PidApp::HTML_CONFIG['header_pid_edit'])
  end
  
# -----------------------------------------------------------------------------------------------
  def test_get_pid
    pid = Pid.first(:url => 'http://www.yahoo.com')
    security_check_basic("/link/#{pid.id}", "get", nil)
    check_login_for_each_user_type("/link/#{pid.id}", PidApp::HTML_CONFIG['header_pid_view'])
    
    # User cannot see a PID that does not belong to them so should get a 403
    post '/user/login', {:login => @user2.login, :password => @pwd}
    get "/link/#{pid.id}"
    assert_equal 403, last_response.status, "Was expecting a 403 because the user should not have access to that PID!"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_unauthorized']), "Was not sent to the unauthorized page!"
    
    pid = Pid.first(:url => 'http://www.google.com')

    # User CAN see a PID they are an Interested party for
    get "/link/#{pid.id}"
    assert last_response.ok?, "Interested user did not receive a 200 status code trying to view a PID they are an Interested party for, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_pid_view']), "Interested user could not get to the Interested PID's page!"
    
    # Make sure a non-existent PID throws a 404
    get "/link/99999999"
    assert last_response.not_found?, "Found the specified PID. status: #{last_response.status}"
    get '/user/logout'
  end
  
# -----------------------------------------------------------------------------------------------
  def test_post_batch
    
  end
  
# -----------------------------------------------------------------------------------------------
  def test_post_search
    # sleep so that the modification date on the pid will differ from the creation date!
    sleep(10)
    
    time_check = Time.now
    
    args = {:userid => '',
            :active => 'off',
            :pid_low => '',
            :pid_high => '',
            :modified_low => '',
            :modified_high => '',
            :created_low => '',
            :created_high => ''}
            
    # Keep in mind that the JSON data of the test page generates the results table via JQuery
    # so we must parse the json object to
    
    args[:url] = 'http://'
    
    # Make sure users can only see their group's PIDs and ones that they are Interested in 
    post '/user/login', {:login => @user.login, :password => @pwd}
    post '/link/search', args # expecting 3 results
    assert last_response.ok?, "Search returned no results for the User! #{last_response.status}"
    json = convert_html_to_json(last_response.body)
    assert_equal 3, json.size, "Expected 3 results for User but found #{json.size}"
    get '/user/logout'
    
    post '/user/login', {:login => @user2.login, :password => @pwd}
    post '/link/search', args # expecting 3 results
    assert last_response.ok?, "Search returned no results for the User 2! #{last_response.status}"
    json = convert_html_to_json(last_response.body)
    assert_equal 2, json.size, "Expected 2 results for User 2 but found #{json.size}"
    get '/user/logout'
    
    # Make sure maintainer can see the PIDs for all groups they maintain
    post '/user/login', {:login => @mgr.login, :password => @pwd}
    post '/link/search', args # expecting 3 results
    assert last_response.ok?, "Search returned no results for the Maintainer! #{last_response.status}"
    json = convert_html_to_json(last_response.body)
    assert_equal 4, json.size, "Expected 4 results for Maintainer but found #{json.size}"
    get '/user/logout'
    
    # Make sure admin can see ALL PIDs
    post '/user/login', {:login => @adm.login, :password => @pwd}
    post '/link/search', args # expecting 3 results
    assert last_response.ok?, "Search returned no results for the Admin! #{last_response.status}"
    json = convert_html_to_json(last_response.body)
    assert_equal 6, json.size, "Expected 6 results for Admin but found #{json.size}"
    
    # Search by specific url
    args[:url] = 'http://www.yahoo.com'
    post '/link/search', args # expecting 3 results
    assert last_response.ok?, "Search returned no results for the specific url search! #{last_response.status}"
    json = convert_html_to_json(last_response.body)
    assert_equal 1, json.size, "Expected 1 results for the specific url search but found #{json.size}"
    args[:url] = ''
    
    # Search by user
    args[:userid] = @user.id
    post '/link/search', args # expecting 3 results
    assert last_response.ok?, "Search returned no results for the specific user search! #{last_response.status}"
    json = convert_html_to_json(last_response.body)
    assert_equal 2, json.size, "Expected 2 results for the specific user search but found #{json.size}"
    args[:userid] = ''
    
    # Search for PID range
    args[:pid_low] = 2
    args[:pid_high] = 4
    post '/link/search', args # expecting 3 results
    assert last_response.ok?, "Search returned no results for the specific pid range search! #{last_response.status}"
    json = convert_html_to_json(last_response.body)
    assert_equal 3, json.size, "Expected 3 results for the specific pid range search but found #{json.size}"
    args[:pid_low] = ''
    args[:pid_high] = ''
    
    # Search returns no results
    pid1 = Pid.first('http://www.yahoo.com')
    pid1.revise({:url => "#{pid1.url}/testing"})
    
    args[:modified_low] = time_check
    args[:modified_high] = Time.now
    post '/link/search', args # expecting 3 results
    assert last_response.ok?, "Search returned no results for the specific modified date range search! #{last_response.status}"
    json = convert_html_to_json(last_response.body)
    assert_equal 1, json.size, "Expected 1 results for the specific modified date range search but found #{json.size}"
    args[:modified_low] = ''
    args[:modified_high] = ''
    
    args[:url] = 'www.abcdefghijklmnop.org'
    post '/link/search', args # expecting 3 results
    assert last_response.ok?, "User did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['pid_search_not_found']), "User did not get a no results messaget!"
    
    get '/user/logout'
  end
  
# -----------------------------------------------------------------------------------------------
  def test_post_pid
    # Test one new PID
    post '/user/login', {:login => @user2.login, :password => @pwd}
    post '/link', {:new_urls => "http://www.ucop.edu"}
    assert last_response.ok?, "User did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_pid_register_success']), "User did not get a positive result!"
    
    # Dead URL
    post '/link', {:new_urls => "http://www.yahoo.com/test/search/12345"}
    assert last_response.ok?, "User did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_pid_register_dead_url']), "User did not get a dead URL result!"
    
    # Bad URL format
    post '/link', {:new_urls => "www.blahblah.com"}
    assert_equal 500, last_response.status, "User did not receive a 500 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['create_pids_some_errors']), "User did not get a failed result!"
    
    # Already existing URL just creates an Interested party
    post '/link', {:new_urls => "http://www.yahoo.com"}
    assert last_response.ok?, "User did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_pid_register_duplicate_url']), "User did not get a failed result!"
    
    # Combination of good PIDs, bad URLs, and duplicates
    post '/link', {:new_urls => "http://www.blahblah.com\nwww.yahoo.com\nhttp://www.yahoo.com\nhttp://www.newone.org"}
    assert_equal 206, last_response.status, "User did not receive a 206 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_pid_register_success']), "User did not get a positive result!"
    assert last_response.body.include?(PidApp::HTML_CONFIG['create_pids_some_errors']), "User did not get a failed result!"
    assert last_response.body.include?(PidApp::HTML_CONFIG['create_pids_some_errors']), "User did not get a failed result!"
    get '/user/logout'
    
    assert !Pid.first(:url => 'http://www.blahblah.com').nil?, 'The PID was not minted!'
    assert_equal 1, Pid.all(:url => 'http://www.yahoo.com').count, 'The system saved a duplicate URL!'
  end
  
# -----------------------------------------------------------------------------------------------
  def test_put_pid
    pid = Pid.first(:url => 'http://www.google.com')
    
    post '/user/login', {:login => @user.login, :password => @pwd}
    put "/link/#{pid.id}", {:url => 'http://news.yahoo.com/', :active => 'on'}
    assert last_response.ok?, "User did not get a 200 after updating a PID, got a #{last_response.status}!"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['pid_update_success']), "Did not receive the success message!"

    # Dead URL
    put "/link/#{pid.id}", {:url => 'http://mail.yahoo.com/', :active => 'on'}
    assert last_response.ok?, "User did not get a 200 after updating a PID, got a #{last_response.status}!"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['pid_revise_dead_url'].gsub('{?}', '')), "Did not receive the Dead URL message!"
    
    # Bad URL format
    put "/link/#{pid.id}", {:url => 'mail.yahoo.com/', :active => 'on'}
    assert last_response.ok?, "User did not receive a 500 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['pid_update_invalid_url']), "Did not receive the failure message!"
        
    pid = Pid.first(:url => 'http://cdlib.org')
    
    # Cannot modify a PID that does not belong to user's group!
    put "/link/#{pid.id}", {:url => 'http://mail.yahoo.com/', :active => 'on'}
    assert_equal 403, last_response.status, "Was expecting a 403 because the user should not be able to edit a PID they do not own!"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_unauthorized']), "Was not sent to the unauthorized page!"
    get '/user/logout'
    
    # Already existing URL just creates an Interested party
    post '/user/login', {:login => @user2.login, :password => @pwd}
    put "/link/#{pid.id}", {:url => 'http://www.yahoo.com', :active => 'on'}
    assert last_response.ok?, "User did not get a 200 after updating a PID, got a #{last_response.status}!"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['pid_duplicate_url'].gsub('{?}', '')), "Did not receive the Duplicate URL message! #{last_response.body}"
    
    # Cannot modify PID that does not exist
    put "/link/999999999", {:url => 'http://www.yahoo_new.com/', :active => 'on'}
    assert last_response.not_found?, "Found the specified PID. status: #{last_response.status}"
    
    get '/user/logout'
  end

# -----------------------------------------------------------------------------------------------
# -----------------------------------------------------------------------------------------------
  def convert_html_to_json(html)
    page = Nokogiri::HTML(last_response.body)
    JSON.parse(page.search('#data').first['value'])
  end

# -----------------------------------------------------------------------------------------------  
  def check_login_for_each_user_type(page, expected_header)
    security_check_basic(page, "get", nil)
    
    # As a user
    post '/user/login', {:login => @user.login, :password => @pwd}
    get page
    assert last_response.ok?, "User did not receive a 200 status code for #{page}, got a #{last_response.status}"
    assert last_response.body.include?(expected_header), "User did not get to #{page}!"
    get '/user/logout'
    
    # As a maintainer
    post '/user/login', {:login => @mgr.login, :password => @pwd}
    get page
    assert last_response.ok?, "Maintainer did not receive a 200 status code for #{page}, got a #{last_response.status}"
    assert last_response.body.include?(expected_header), "Maintainer did not get to #{page}!"
    get '/user/logout'
    
    # As an admin
    post '/user/login', {:login => @adm.login, :password => @pwd}
    get page
    assert last_response.ok?, "Admin did not receive a 200 status code for #{page}, got a #{last_response.status}"
    assert last_response.body.include?(expected_header), "Admin did not get to #{page}!"
    get '/user/logout'
  end
  
=begin  
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
=end
  
end
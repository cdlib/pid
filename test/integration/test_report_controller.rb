require_relative '../test_helper'
require 'open-uri'
require 'nokogiri'
require 'json'

class TestReportController < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    PidApp
  end

  def setup
    Pid.flush!
    User.flush!
    Group.flush!
    Maintainer.flush!
    Interested.flush!
    SkipCheck.flush!
    
    @pwd = 'secret'
    
    @group = Group.new(:id => 'UCLA', :name => 'test_group')
    @user = User.new(:login => 'test_user', :name => 'Test User', :password => @pwd, :email => 'test@example.org')
    
    @group.users << @user
    @group.save
    
    SkipCheck.new(:domain => 'yahoo.com', :created_at => Time.now, :group => @group)
    
    Pid.mint(:url => 'http://cdlib.org', :username => @user.login, :change_category => 'Test', :group => @group)
    Pid.mint(:url => 'http://www.google.com', :username => @user.login, :change_category => 'Test', :group => @group)
    Pid.mint(:url => 'http://www.yahoo.com', :username => @user.login, :change_category => 'Test', :group => @group)
    Pid.mint(:url => 'http://news.yahoo.com', :username => @user.login, :change_category => 'Test', :group => @group)
    Pid.mint(:url => 'http://sports.yahoo.com', :username => @user.login, :change_category => 'Test', :group => @group)
    Pid.mint(:url => 'http://www.huffingtonpost.com', :username => @user.login, :change_category => 'Test', :group => @group)
    Pid.mint(:url => 'http://www.dailybeast.com', :username => @user.login, :change_category => 'Test', :group => @group)
    Pid.mint(:url => 'http://www.gizmodo.com', :username => @user.login, :change_category => 'Test', :group => @group)
    Pid.mint(:url => 'http://www.wikipedia.org', :username => @user.login, :change_category => 'Test', :group => @group)
    Pid.mint(:url => 'http://www.apple.com', :username => @user.login, :change_category => 'Test', :group => @group)
    Pid.mint(:url => 'http://www.samsung.com', :username => @user.login, :change_category => 'Test', :group => @group)
  end

# -----------------------------------------------------------------------------------------------
  def test_get_main_menu
    security_check_basic("/report", "get", nil)

    post '/user/login', {:login => @user.login, :password => @pwd}
    get '/report'
    assert last_response.ok?, "Expected a 200 but got a #{last_response.status}!"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_reports']), 'Did not get the main report menu!'
    get '/user/logout'
  end

# -----------------------------------------------------------------------------------------------  
  def test_get_inactive_pids_report
    security_check_basic("/report/inactive", "get", nil)

    Pid.first(:url => 'http://www.huffingtonpost.com').revise({:deactivated => true, :dead_pid_url => dead_pid_url})
    Pid.first(:url => 'http://www.dailybeast.com').revise({:deactivated => true, :dead_pid_url => dead_pid_url})

    post '/user/login', {:login => @user.login, :password => @pwd}
    get '/report/inactive'
    assert last_response.ok?, "Expected a 200 but got a #{last_response.status}!"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_report_inactive']), 'Did not get the inactive report!'
    json = convert_html_to_json(last_response.body)
    assert_equal 2, json.size, "Expected 2 results but found #{json.size}"
    get '/user/logout'
  end
  
# -----------------------------------------------------------------------------------------------
  def test_get_invalid_urls_report
    security_check_basic("/report/invalid", "get", nil)

    post '/user/login', {:login => @user.login, :password => @pwd}
    get '/report/invalid'
    assert last_response.ok?, "Expected a 200 but got a #{last_response.status}!"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_report_invalid']), 'Did not get the invalid report!'
    json_txt = Nokogiri::HTML(last_response.body).search('#not_found_data').first['value']
    json = JSON.parse(json_txt)
    assert_equal 7, json.size, "Expected 7 results but found #{json.size}}"
    get '/user/logout'
  end
  
# -----------------------------------------------------------------------------------------------
  def test_get_duplicate_urls_report
    # The system does not allow duplicates to be created. Need to do direct mysql to add some to test this
  end
  
# -----------------------------------------------------------------------------------------------
  def test_get_maintenance_stats_report
    
  end
  
end
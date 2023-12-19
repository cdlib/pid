ENV['RACK_ENV'] = 'test'
ENV['DATABASE_URL'] = "sqlite::memory:"
$LOAD_PATH.unshift(File.absolute_path(File.join(File.dirname(__FILE__), '../')))
require 'nokogiri'
require 'json'
require 'fakeredis'

require 'app'
load 'db/schema.rb'

require 'minitest/autorun'
require 'capybara'
require 'capybara/dsl'
require 'capybara/minitest'
require 'selenium-webdriver'

Capybara.app = PidApp

chrome_binary_path = '/opt/google/chrome/chrome-linux64/chrome'
chrome_driver_path = '/usr/local/bin/chromedriver-linux64/chromedriver'
Selenium::WebDriver::Chrome::Service.driver_path = chrome_driver_path

Capybara.register_driver :chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  options.add_argument('--disable-gpu')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-extensions')
  options.add_argument("--binary=#{chrome_binary_path}")
  options.add_option('goog:loggingPrefs', { browser: 'ALL', performance: 'ALL' })

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.server_port = 3001
Capybara.app_host = "http://localhost:#{Capybara.server_port}" 
Capybara.default_driver = :chrome_headless
Capybara.javascript_driver = :chrome_headless

# --------------------------------------------------------------------------------------------------------------
# Helper methods for controller security checks
# --------------------------------------------------------------------------------------------------------------
  def dead_pid_url
    PidApp::APP_CONFIG['dead_pid_url']
  end

  def security_check_administrator(page, method, args, test_maintainer)
    security_check_basic(page, method, args)
    
    # logged in as a non super admin or group maintainer should fail
    post '/user/login', {login: @user.login, password: @pwd}
    invoke_page(method, page, args)
    assert_equal 403, last_response.status, "Was expecting a 403 because the user should not have access to #{method} to #{page}!"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_unauthorized']), "Was not sent to the unauthorized page when trying to #{method} to #{page}! #{last_response.body}"
    post '/user/logout'
    
    # if the maintainer should be tested as well
    if test_maintainer
      post '/user/login', { login: @mgr.login, password: @pwd }
      invoke_page(method, page, args)
      assert_equal 403, last_response.status, "Was expecting a 403 because the user should not have access to #{method} to #{page}!"
      assert last_response.body.include?(PidApp::HTML_CONFIG['header_unauthorized']), "Was not sent to the unauthorized page!"
      post '/user/logout'
    end
  end
  
  def security_check_basic(page, method, args)
    # not logged in
    invoke_page(method, page, args)
    assert_equal 401, last_response.status, "Did not receive a 401 when not logged in! Got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_login']), "Was not sent to the login page!"
  end
  
  def invoke_page(method, page, args)     
    if method == 'post'
      post page, args
    elsif method == 'put'
      put page, args
    elsif method == 'delete'
      delete page, args
    else
      get page 
    end
  end
  
  def convert_html_to_json(html)
    page = Nokogiri::HTML(html)
    JSON.parse(page.search('#data').first['value'])
  end
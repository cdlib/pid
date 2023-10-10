ENV['RACK_ENV'] = 'test'
ENV['DATABASE_URL'] = "sqlite::memory:"
$LOAD_PATH.unshift(File.absolute_path(File.join(File.dirname(__FILE__), '../')))
require 'rubygems'
require 'bundler'
Bundler.require(:default, ENV['RACK_ENV'].to_sym)
#require 'test/unit'
require 'app'
require "minitest/autorun"
require 'capybara/dsl'
require 'capybara/poltergeist'

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, {
        :js_errors => true,
        :run_server => false
    })
end

Capybara.configure do |config|
  config.default_driver = :poltergeist
end

Capybara.javascript_driver = :poltergeist


# --------------------------------------------------------------------------------------------------------------
# Helper methods for controller security checks
# --------------------------------------------------------------------------------------------------------------
  def dead_pid_url
    PidApp::APP_CONFIG['dead_pid_url']
  end

  def security_check_administrator(page, method, args, test_maintainer)
    security_check_basic(page, method, args)
    
    # logged in as a non super admin or group maintainer should fail
    post '/user/login', { :login => @user.login, :password => @pwd }
    invoke_page(method, page, args)
    assert_equal 403, last_response.status, "Was expecting a 403 because the user should not have access to #{method} to #{page}!"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_unauthorized']), "Was not sent to the unauthorized page when trying to #{method} to #{page}! #{last_response.body}"
    post '/user/logout'
    
    # if the maintainer should be tested as well
    if test_maintainer
      post '/user/login', { :login => @mgr.login, :password => @pwd }
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
    if method == "post"
      post page, args
    elsif method == "put"
      put page, args
    elsif method == "delete"
      delete page, args
    else
      get page 
    end
  end
  
# -----------------------------------------------------------------------------------------------
  def convert_html_to_json(html)
    page = Nokogiri::HTML(last_response.body)
    JSON.parse(page.search('#data').first['value'])
  end
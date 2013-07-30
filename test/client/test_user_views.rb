require_relative '../test_helper'

class UserClientTestApp < Test::Unit::TestCase
  include Rack::Test::Methods
  include Capybara::DSL

  MESSAGE_CONFIG = YAML.load_file('conf/message.yml')
  HTML_CONFIG = YAML.load_file('conf/html.yml')
  
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
    @user = User.new(:login => 'test_user', :name => 'Test User', :password => @pwd, :email => 'test@example.org')
    
    @group.users << @user
    @group.save
    
    Capybara.app = PidApp.new
  end
  
# --------------------------------------------------------------------------------------------------------
# Login page tests
# --------------------------------------------------------------------------------------------------------
  def test_login_load
    visit '/user/login'
    
    assert page.has_selector?('#login'), 'No userid input found!'
    assert page.has_selector?('#password'), 'No password input found!'
    assert page.has_selector?('#submit'), 'No submit button found!'
  end
  
  def test_login_missing_password
    visit '/user/login'
    
    fill_in 'login', with: @user.login
    click_button 'submit'
  
    assert page.has_content?(MESSAGE_CONFIG['no_password']), 'Did not receive the missing password message!'
  end

  def test_login_missing_userid
    visit '/user/login'
    
    fill_in 'password', with: @pwd
    click_button 'submit'
  
    assert page.has_content?(MESSAGE_CONFIG['no_login']), 'Did not receive the missing userid message!'
  end  
  
  def test_login_invalid
    login('bad_user', @pwd)
    assert !page.has_content?('session_id'), 'Was able to login - found session id info!'
    assert page.has_content?(MESSAGE_CONFIG['invalid_login']), 'Was able to login - did not get invalid login message!'
  end
  
  def test_login_valid
    login(@user.login, @pwd)
    assert page.has_content?('session_id'), 'Was unable to login - no session established!'
  end
  
# --------------------------------------------------------------------------------------------------------
# Logout page tests 
# --------------------------------------------------------------------------------------------------------
  def test_logout_load
    login(@user.login, @pwd)
    assert page.has_content?('session_id'), 'Was unable to login - no session established!'
    
    visit '/user/logout'
  
    assert page.has_selector?('#login'), 'No userid input found!'
    assert page.has_selector?('#password'), 'No password input found!'
    assert page.has_selector?('#submit'), 'No submit button found!'
  
    assert !page.has_content?('session_id'), 'Was able to login - found session id info!'
  end
  
# --------------------------------------------------------------------------------------------------------
# Forgotten password page tests 
# --------------------------------------------------------------------------------------------------------
  def test_forgotten_password_load
    visit '/user/forgot'
    
    assert page.has_selector?('#login'), 'No userid input found!'
  end
  
  def test_forgotten_password_not_available_when_logged_in
    login(@user.login, @pwd)
    assert page.has_content?('session_id'), 'Was unable to login - no session established!'
    
    visit '/user/forgot'
    
    assert !page.has_selector?('#login'), 'Was able to access the forgotten password page while logged in!'
  end

  def test_forgotten_password_bad_userid
    visit '/user/forgot'
    
    fill_in 'login', with: 'bad_user'
    
    assert page.has_selector?('.not_ok'), "An invalid userid did not display the red X icon!"
  end

  def test_forgotten_password_valid_userid
    visit '/user/forgot'
    
    fill_in 'login', with: @user.login
    
    assert page.has_selector?('.ok'), "A valid userid did not display the checkmark icon!"
  end
  
# --------------------------------------------------------------------------------------------------------
# Reset password page tests 
# --------------------------------------------------------------------------------------------------------
  def test_reset_password_load
    
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




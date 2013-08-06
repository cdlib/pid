require_relative '../test_helper'

class UserClientTestApp < Test::Unit::TestCase
  include Rack::Test::Methods
  include Capybara::DSL
  
  Capybara.app = PidApp.new
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
    @user = User.new(:login => 'test_user', :name => 'Test User', :password => @pwd, 
                      :email => 'test@example.org', :super => true)
    @mgr = User.new(:login => 'test_mgr', :name => 'Test Manager', :password => @pwd, 
                      :email => 'mgr@example.org')
    @group.users << @user
    @group.users << @mgr
    @group.save
    
    Maintainer.new(:group => @group, :user => @mgr).save
  end
  
  def teardown
    Capybara.reset_sessions!
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
  
# --------------------------------------------------------------------------------------------------------
# Logout page tests 
# --------------------------------------------------------------------------------------------------------
  def test_logout_load
    login(@user.login, @pwd)

    assert page.driver.cookies.include?('rack.session'), 'Was unable to login!'

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
    reset_params = request_password_reset(@user.login)

    visit "/user/reset?n=#{reset_params[:n]}&c=#{reset_params[:c]}"

    assert page.has_selector?('#password'), 'Cannot open the reset password page - no password field found!'
    assert page.has_selector?('#confirm'), 'Cannot open the reset password page - no password confirmation field found!'
  end

  def test_reset_password_not_available_when_logged_in
    reset_params = request_password_reset(@user.login)

    login(@user.login, @pwd)
    
    visit "/user/reset?n=#{reset_params[:n]}&c=#{reset_params[:c]}"
    
    assert !page.has_selector?('#login'), 'Was able to access the reset password page while logged in!'
  end

  def test_reset_missing_fields
    reset_params = request_password_reset(@user.login)

    visit "/user/reset?n=#{reset_params[:n]}&c=#{reset_params[:c]}"

    click_button 'submit'
    assert !page.has_content?("#{HTML_CONFIG['form_new_password']} cannot be blank!"), 'Was able to leave the password blank!'
    assert !page.has_content?("#{HTML_CONFIG['form_confirm_password']} cannot be blank!"), 'Was able to leave the password confirmation blank!'

    fill_in 'password', with: @pwd
    click_button 'submit'
    assert !page.has_content?("#{HTML_CONFIG['form_confirm_password']} cannot be blank!"), 'Was able to leave the password confirmation blank!'

    fill_in 'password', with: ''
    fill_in 'confirm', with: @pwd
    click_button 'submit'
    assert !page.has_content?("#{HTML_CONFIG['form_new_password']} cannot be blank!"), 'Was able to leave the password blank!'
  end

  def test_reset_password_mismatch
    reset_params = request_password_reset(@user.login)

    visit "/user/reset?n=#{reset_params[:n]}&c=#{reset_params[:c]}"

    fill_in 'password', with: 'change_it'
    fill_in 'confirm', with: 'change'
    click_button 'submit'
    assert !page.has_content?("#{HTML_CONFIG['form_new_password']} and #{HTML_CONFIG['form_confirm_password']} MUST match!"), 'Was able to submit passwords that do not match!'
  end

# --------------------------------------------------------------------------------------------------------
# User list page tests 
# --------------------------------------------------------------------------------------------------------
  def test_list_users_load
    login(@user.login, @pwd)
    
    visit "/user/list"

    assert page.has_content?(HTML_CONFIG['th_email']), 'The email column header was not found!'
    assert page.has_content?(HTML_CONFIG['th_name']), 'The name column header was not found!'
  end

# --------------------------------------------------------------------------------------------------------
# User show page tests 
# --------------------------------------------------------------------------------------------------------
  def test_show_user_load
    login(@user.login, @pwd)
    
    visit "/user/#{@user.id}"

    assert page.has_selector?('#group'), 'The group field could not be found!'
    assert page.has_selector?('#email'), 'The email field was not found!'
  end

  def test_show_user_required_fields
    login(@user.login, @pwd)
    
    visit "/user/#{@user.id}"
    
    fill_in 'login', with: '   '
    fill_in 'name', with: ''
    fill_in 'email', with: ''
    click_button 'submit'
    assert page.has_content?("#{HTML_CONFIG['form_userid'].gsub(':', '')} cannot be blank!"), 'Was able to submit a blank user id!'
    assert page.has_content?("#{HTML_CONFIG['form_name'].gsub(':', '')} cannot be blank!"), 'Was able to submit a blank name!'
    assert page.has_content?("#{HTML_CONFIG['form_email'].gsub(':', '')} cannot be blank!"), 'Was able to submit a blank email!'
  end

  def test_show_user_invalid_email
    login(@user.login, @pwd)
    
    visit "/user/#{@user.id}"
    
    fill_in 'email', with: 'this.is@abademail'
    click_button 'submit'
    assert page.has_content?("is not a valid email address!"), 'Was able to enter an invalid email!'
  end

  def test_show_user_password_mismatch
    login(@user.login, @pwd)
    
    visit "/user/#{@user.id}"

    fill_in 'password', with: 'change_it'
    fill_in 'confirm', with: 'change'
    click_button 'submit'
    assert page.has_content?("#{HTML_CONFIG['form_new_password'].gsub(':', '')} and #{HTML_CONFIG['form_confirm_password'].gsub(':', '')} MUST match!"), 'Was able to submit passwords that do not match!'
  end

  def test_show_userid_unique
    login(@user.login, @pwd)
    
    visit "/user/#{@user.id}"

    fill_in 'login', with: 'uniqueguy'
    assert page.has_selector?('.ok'), "A unique userid is displaying a red X icon!"
  end

  def test_show_user_userid_already_used
    user = User.new(:login => 'new_user', :name => 'New User', :password => @pwd, 
                      :email => 'new@example.org', :group => @group)
    user.save

    login(user.login, @pwd)
    
    visit "/user/#{user.id}"
    fill_in 'login', with: @user.login
    assert page.has_selector?('.not_ok'), "An already used userid is displaying a green checkmark!"
  end

  def test_show_user_ajax_put
    login(@user.login, @pwd)
    
    visit "/user/#{@user.id}"

    fill_in 'email', with: 'this.is@goodemail.org'
    click_button 'submit'
    assert page.has_content?(MESSAGE_CONFIG['user_update_success']), 'Was unable to edit the user!'
  end

# --------------------------------------------------------------------------------------------------------
# User register page tests 
# --------------------------------------------------------------------------------------------------------
  def test_register_user_load
    login(@user.login, @pwd)

    visit "/user/register"

    assert page.has_selector?('#group'), 'The group field could not be found!'
    assert page.has_selector?('#email'), 'The email field was not found!'
  end

  def test_register_user_required_fields
    login(@user.login, @pwd)
    
    visit '/user/register'
    
    fill_in 'login', with: '   '
    fill_in 'name', with: ''
    fill_in 'email', with: ''
    fill_in 'password', with: ''
    fill_in 'confirm', with: ''
    click_button 'submit'

    assert page.has_content?("#{HTML_CONFIG['form_userid'].gsub(':', '')} cannot be blank!"), 'Was able to submit a blank user id!'
    assert page.has_content?("#{HTML_CONFIG['form_name'].gsub(':', '')} cannot be blank!"), 'Was able to submit a blank name!'
    assert page.has_content?("#{HTML_CONFIG['form_email'].gsub(':', '')} cannot be blank!"), 'Was able to submit a blank email!'
    assert page.has_content?("#{HTML_CONFIG['form_new_password'].gsub(':', '')} cannot be blank!"), 'Was able to submit a blank password!'
    assert page.has_content?("#{HTML_CONFIG['form_confirm_password'].gsub(':', '')} cannot be blank!"), 'Was able to submit a blank password confirmation!'
  end

  def test_register_user_invalid_email
    login(@user.login, @pwd)
    
    visit '/user/register'
    
    fill_in 'login', with: 'tester2'
    fill_in 'name', with: 'Second tester'
    fill_in 'email', with: 'this.is@abademail'
    fill_in 'password', with: 'password'
    fill_in 'confirm', with: 'password'
    click_button 'submit'
    
    assert page.has_content?("is not a valid email address!"), 'Was able to enter an invalid email!'
  end

  def test_register_user_password_mismatch
    login(@user.login, @pwd)

    visit '/user/register'

    fill_in 'login', with: 'tester2'
    fill_in 'name', with: 'Second tester'
    fill_in 'email', with: 'this.is@example.org'
    fill_in 'password', with: 'change_it'
    fill_in 'confirm', with: 'change'
    click_button 'submit'
    
    assert page.has_content?("#{HTML_CONFIG['form_new_password'].gsub(':', '')} and #{HTML_CONFIG['form_confirm_password'].gsub(':', '')} MUST match!"), 'Was able to submit passwords that do not match!'
  end

  def test_register_userid_unique
    login(@user.login, @pwd)

    visit '/user/register'

    fill_in 'login', with: 'uniqueguy'
    assert page.has_selector?('.ok'), "A unique userid is displaying a red X icon!"
  end

  def test_register_user_userid_already_used
    user = User.new(:login => 'new_user', :name => 'New User', :password => @pwd, 
                      :email => 'new@example.org', :group => @group)

    login(@user.login, @pwd)

    visit '/user/register'

    fill_in 'login', with: @user.login
    assert page.has_selector?('.not_ok'), "An already used userid is displaying a green checkmark!"
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
  
  def request_password_reset(login)
    visit '/user/forgot'

    fill_in 'login', with: login
    click_button 'reset'

    user = User.get(@user.id)

    {:n => user.id, :c => user.reset_code}
  end

end




require_relative '../test_helper'

class UserClientTestApp < Minitest::Test
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
    @user = User.new(login: 'testuser', name: 'Test User', password: @pwd, email: 'purl-test-user@cdlib.org')
    @mgr = User.new(login: 'testmgr', name: 'Test Manager', password: @pwd, email: 'purl-test-mgr@cdlib.org')
    @group.users << @user
    @group.users << @mgr
    @group.save
    
    Maintainer.create(group: @group, user: @mgr)
  end
  
  def teardown
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end
  
# --------------------------------------------------------------------------------------------------------
# Login page tests
# --------------------------------------------------------------------------------------------------------
  def test_login_missing_password
    visit '/user/login'

    fill_in 'login', with: @user.login
    execute_script('$("#login").trigger("change");')

    click_button 'submit'
    assert page.has_content?(PidApp::MESSAGE_CONFIG['no_password']), 'Did not receive the missing password message!'
  end

# --------------------------------------------------------------------------------------------------------
  def test_login_missing_userid
    visit '/user/login'
    
    fill_in 'password', with: @pwd

    click_button 'submit'
    assert page.has_content?(PidApp::MESSAGE_CONFIG['no_login']), 'Did not receive the missing userid message!'
  end  
  
# --------------------------------------------------------------------------------------------------------
# Forgotten password page tests 
# --------------------------------------------------------------------------------------------------------
  # def test_forgotten_password_bad_userid
  #   visit '/user/forgot'
    
  #   fill_in 'login', with: 'baduser'
  #   execute_script('$("#login").trigger("change");')

  #   assert page.has_selector?('.not_ok'), "An invalid userid did not display the red X icon!"
  # end

# --------------------------------------------------------------------------------------------------------
  # def test_forgotten_password_valid_userid
  #   visit '/user/forgot'
    
  #   fill_in 'login', with: @user.login
  #   execute_script('$("#login").trigger("change");')

  #   assert page.has_selector?('.ok'), "A valid userid did not display the checkmark icon!"
  # end
  
# --------------------------------------------------------------------------------------------------------
# Reset password page tests 
# --------------------------------------------------------------------------------------------------------
  def test_reset_missing_fields
    reset_params = request_password_reset(@user.email)

    visit "/user/reset?n=#{reset_params[:n]}&c=#{reset_params[:c]}"
    click_button 'submit'
    assert !page.has_content?("#{PidApp::HTML_CONFIG['form_new_password']} cannot be blank!"), 'Was able to leave the password blank!'
    assert !page.has_content?("#{PidApp::HTML_CONFIG['form_confirm_password']} cannot be blank!"), 'Was able to leave the password confirmation blank!'

    fill_in 'password', with: @pwd
    click_button 'submit'
    assert !page.has_content?("#{PidApp::HTML_CONFIG['form_confirm_password']} cannot be blank!"), 'Was able to leave the password confirmation blank!'

    fill_in 'password', with: ''
    fill_in 'confirm', with: @pwd
    click_button 'submit'
    assert !page.has_content?("#{PidApp::HTML_CONFIG['form_new_password']} cannot be blank!"), 'Was able to leave the password blank!'
  end

# --------------------------------------------------------------------------------------------------------
  def test_reset_password_mismatch
    reset_params = request_password_reset(@user.email)

    visit "/user/reset?n=#{reset_params[:n]}&c=#{reset_params[:c]}"

    fill_in 'password', with: 'change_it'
    fill_in 'confirm', with: 'change'
    click_button 'submit'
    assert !page.has_content?("#{PidApp::HTML_CONFIG['form_new_password']} and #{PidApp::HTML_CONFIG['form_confirm_password']} MUST match!"), 'Was able to submit passwords that do not match!'
  end

# --------------------------------------------------------------------------------------------------------
# User show page tests 
# --------------------------------------------------------------------------------------------------------
  def test_show_user_required_fields
    login(@user.login, @pwd)
    
    visit "/user/#{@user.id}"
    
    fill_in 'login', with: '   '
    execute_script('$("#login").trigger("change");')

    fill_in 'name', with: ''
    fill_in 'email', with: ''
    click_button 'submit'
    assert page.has_content?("#{PidApp::HTML_CONFIG['form_userid'].gsub(':', '')} cannot be blank!"), 'Was able to submit a blank user id!'
    assert page.has_content?("#{PidApp::HTML_CONFIG['form_name'].gsub(':', '')} cannot be blank!"), 'Was able to submit a blank name!'
    assert page.has_content?("#{PidApp::HTML_CONFIG['form_email'].gsub(':', '')} cannot be blank!"), 'Was able to submit a blank email!'
  end

# --------------------------------------------------------------------------------------------------------
  def test_show_user_invalid_email
    login(@user.login, @pwd)
    
    visit "/user/#{@user.id}"
    
    fill_in 'email', with: 'this.is@abademail'
    click_button 'submit'
    assert page.has_content?("is not a valid email address!"), 'Was able to enter an invalid email!'
  end

# --------------------------------------------------------------------------------------------------------
  def test_show_user_password_mismatch
    login(@user.login, @pwd)
    
    visit "/user/#{@user.id}"

    fill_in 'password', with: 'changeit'
    fill_in 'confirm', with: 'change'
    click_button 'submit'
    assert page.has_content?("#{PidApp::HTML_CONFIG['form_new_password'].gsub(':', '')} and #{PidApp::HTML_CONFIG['form_confirm_password'].gsub(':', '')} MUST match!"), 'Was able to submit passwords that do not match!'
  end

# --------------------------------------------------------------------------------------------------------
  def test_show_userid_unique
    login(@user.login, @pwd)
    
    visit "/user/#{@user.id}"

    fill_in 'login', with: 'uniqueguy'
    execute_script('$("#login").trigger("change");')

    assert page.has_selector?('.ok'), "A unique userid is displaying a red X icon!"
  end

# --------------------------------------------------------------------------------------------------------
  def test_show_user_userid_already_used
    User.create(login: 'newuser', name: 'New User', password: @pwd, email: 'new@example.org', group: @group)

    login(@mgr.login, @pwd)
    
    visit "/user/#{@user.id}"
    
    fill_in 'login', with: 'newuser'
    execute_script('$("#login").trigger("change");')

    fill_in 'name', with: 'New User Again'

    assert page.has_selector?('.not_ok'), "An already used userid is displaying a green checkmark! #{page.body}"
  end

# --------------------------------------------------------------------------------------------------------
  def test_show_user_ajax_put
    login(@user.login, @pwd)
    
    visit "/user/#{@user.id}"

    fill_in 'email', with: 'this.is@goodemail.org'
    click_button 'submit'
    
    assert page.has_content?(PidApp::MESSAGE_CONFIG['user_update_success']), "Was unable to edit the user! #{page.body}"
  end

# --------------------------------------------------------------------------------------------------------
# User register page tests 
# --------------------------------------------------------------------------------------------------------
  def test_register_user_required_fields
    login(@mgr.login, @pwd)
    
    visit '/user/register'
    
    fill_in 'login', with: '   '
    execute_script('$("#login").trigger("change");')

    fill_in 'name', with: ''
    fill_in 'email', with: ''
    fill_in 'password', with: ''
    fill_in 'confirm', with: ''
    click_button 'submit'

    assert page.has_content?("#{PidApp::HTML_CONFIG['form_userid'].gsub(':', '')} cannot be blank!"), 'Was able to submit a blank user id!'
    assert page.has_content?("#{PidApp::HTML_CONFIG['form_name'].gsub(':', '')} cannot be blank!"), 'Was able to submit a blank name!'
    assert page.has_content?("#{PidApp::HTML_CONFIG['form_email'].gsub(':', '')} cannot be blank!"), 'Was able to submit a blank email!'
    assert page.has_content?("#{PidApp::HTML_CONFIG['form_new_password'].gsub(':', '')} cannot be blank!"), 'Was able to submit a blank password!'
    assert page.has_content?("#{PidApp::HTML_CONFIG['form_confirm_password'].gsub(':', '')} cannot be blank!"), 'Was able to submit a blank password confirmation!'
  end

# --------------------------------------------------------------------------------------------------------
  def test_register_user_invalid_email
    login(@mgr.login, @pwd)
    
    visit '/user/register'
    
    fill_in 'login', with: 'secondtester'
    execute_script('$("#login").trigger("change");')

    fill_in 'name', with: 'Second tester'
    fill_in 'email', with: 'this.is@abademail'
    fill_in 'password', with: 'password'
    fill_in 'confirm', with: 'password'
    click_button 'submit'
    
    assert page.has_content?("is not a valid email address!"), 'Was able to enter an invalid email!'
  end

# --------------------------------------------------------------------------------------------------------
  def test_register_user_password_mismatch
    login(@mgr.login, @pwd)

    visit '/user/register'

    fill_in 'login', with: 'secondtester'
    execute_script('$("#login").trigger("change");')

    fill_in 'name', with: 'Second tester'
    fill_in 'email', with: 'this.is@example.org'
    fill_in 'password', with: 'change_it'
    fill_in 'confirm', with: 'change'
    click_button 'submit'
    
    assert page.has_content?("#{PidApp::HTML_CONFIG['form_new_password'].gsub(':', '')} and #{PidApp::HTML_CONFIG['form_confirm_password'].gsub(':', '')} MUST match!"), 'Was able to submit passwords that do not match!'
  end

# --------------------------------------------------------------------------------------------------------
  def test_register_userid_unique
    login(@mgr.login, @pwd)

    visit '/user/register'

    fill_in 'login', with: 'uniqueguy'
    execute_script('$("#login").trigger("change");')

    assert page.has_selector?('.ok'), "A unique userid is displaying a red X icon!"
  end

# --------------------------------------------------------------------------------------------------------
  def test_register_user_userid_already_used
    User.create(login: 'newuser', name: 'New User', password: @pwd, email: 'new@example.org', group: @group)

    login(@mgr.login, @pwd)

    visit '/user/register'

    fill_in 'login', with: 'newuser'
    execute_script('$("#login").trigger("change");')

    fill_in 'name', with: 'Another user'
    assert page.has_selector?('.not_ok'), "An already used userid is displaying a green checkmark! #{page.body}"
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
  
# -------------------------------------------------------------------------------------------------------- 
  def request_password_reset(email)
    visit '/user/forgot'

    fill_in 'email', with: email
    click_button 'reset'

    user = User.find_by(id: @user.id)

    { n: user.id, c: user.reset_code }
  end

end




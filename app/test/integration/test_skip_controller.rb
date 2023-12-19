require_relative '../test_helper'

class TestSkipController < Minitest::Test
  include Rack::Test::Methods

  def app
    PidApp
  end

  def setup
    Pid.flush!
    SkipCheck.flush!
    User.flush!
    Group.flush!
    
    @pwd = 'secret'

    @group = Group.create(id: 'UCLA', name: 'test_group')

    @adm = User.create(login: 'testadmin', name: 'Test Administrator', password: @pwd, email: 'admin@example.org', super: true, group: @group)
    @user = User.create(login: 'testuser', name: 'Test User', password: @pwd, email: 'test@example.org', group: @group)
    @mgr = User.create(login: 'testmanager', name: 'Test Manager', password: @pwd, email: 'mgr@example.org', group: @group)

    Maintainer.create(group: @group, user: @mgr)
    
    SkipCheck.create(domain: 'www.yahoo.com', created_at: Time.now, group: @group.id)
    SkipCheck.create(domain: 'www.huffingtonpost.com', created_at: Time.now, group: @group.id)
  end

# ---------------------------------------------------------------
# Test page get 
# ---------------------------------------------------------------
  def test_get_skip
    security_check_administrator("/skip", 'get', nil, false)
    
    # logged in as a Manager/Maintainer
    post '/user/login', { login: @mgr.login, password: @pwd }
    get '/skip'
    assert last_response.ok?, 'Unable to access the Skip Check page as a manager!'
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_skip_check_list']), 'Did not get the skip check list page!'
    post '/user/logout'

    # logged in as a super admin
    post '/user/login', { login: @adm.login, password: @pwd }
    get '/skip'
    assert last_response.ok?, 'Unable to access the Skip Check page as a super admin!'
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_skip_check_list']), 'Did not get the skip check list page!'
    post '/user/logout'
  end

# ---------------------------------------------------------------
# Test page post
# ---------------------------------------------------------------
  def test_post_skip
    security_check_administrator('/skip', 'post', { domain: 'www.google.com' }, false)
    
    # logged in as a Manager/Maintainer
    post '/user/login', { login: @mgr.login, password: @pwd }
    # create a new skip check
    post '/skip', { domain: 'www.google.com' }
    assert last_response.ok?, 'Unable to create a new Skip Check!'
    assert SkipCheck.find_by(domain: 'www.google.com'), 'Could not load the newly created skip check!'
    post '/user/logout'

    # logged in as a super admin
    post '/user/login', { login: @adm.login, password: @pwd }
    # create a new skip check
    post '/skip', { domain: 'www.cdlib.org' }
    assert last_response.ok?, 'Unable to create a new Skip Check!'
    assert SkipCheck.find_by(domain: 'www.cdlib.org'), 'Could not load the newly created skip check!'
    # attempt to create a skip check for a domain that already exists
    post '/skip', { domain: 'yahoo.com' }
    assert_equal 500, last_response.status, 'Was able to create a skip check for an already existing domain!'
    # attempt to create a skip check for a domain that already exists
    post '/skip', { domain: 'www.yahoo.com/1' }
    assert_equal 500, last_response.status, 'Was able to create a skip check for an already existing domain!'

    post '/user/logout'
  end
  
# ---------------------------------------------------------------
# Test page delete
# ---------------------------------------------------------------
  def test_delete_skip
    grp = Group.create(id: 'OTHER', name: 'Other Group')

    SkipCheck.create(domain: 'www.google.com', created_at: Time.now, group: grp.id)

    security_check_administrator('/skip', 'delete', { domain: 'www.google.com' }, false)

    # logged in as a Manager/Maintainer
    post '/user/login', { login: @mgr.login, password: @pwd }
    # delete a skip check
    delete '/skip', { domain: 'www.yahoo.com' }
    assert last_response.ok?, "Unable to delete the Skip Check as a manager! #{last_response.status}"
    # attempt to delete another group's skip check
    delete '/skip', { domain: 'www.google.com' }
    assert_equal 403, last_response.status, 'Was able to delete another groups skip check!'
    post '/user/logout'

    # logged in as a super admin
    post '/user/login', { login: @adm.login, password: @pwd }
    # delete a skip check
    delete '/skip', { domain: 'www.huffingtonpost.com' }
    assert last_response.ok?, 'Unable to delete the Skip Check as a super admin!'
    # attempt to delete a skip check that doesn't exist
    delete '/skip', { domain: 'www.cdlib.org' }
    assert last_response.not_found?, 'Was able to delete a Skip Check that doesnt exist!'
    post '/user/logout'
  end
  
end
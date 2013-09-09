require_relative '../test_helper'

class TestSkipController < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    PidApp
  end

  def setup
    SkipCheck.flush!
    User.flush!
    Group.flush!
    
    @pwd = 'secret'

    @group = Group.new(:id => 'UCLA', :name => 'test_group')
    @group.save

    @adm = User.new(:login => 'test_admin', :name => 'Test Administrator', :password => @pwd, :email => 'admin@example.org', :super => true, :group => @group)
    @user = User.new(:login => 'test_user', :name => 'Test User', :password => @pwd, :email => 'test@example.org', :group => @group)
    @mgr = User.new(:login => 'test_mgr', :name => 'Test Manager', :password => @pwd, :email => 'mgr@example.org', :group => @group)
    
    @adm.save
    @mgr.save
    @user.save

    Maintainer.new(:group => @group, :user => @mgr).save
    
    SkipCheck.new(:domain => 'www.yahoo.com', :created_at => Time.now, :group => @group.id).save
    SkipCheck.new(:domain => 'www.huffingtonpost.com', :created_at => Time.now, :group => @group.id).save
  end

# ---------------------------------------------------------------
# Test page get 
# ---------------------------------------------------------------
  def test_get_skip
    # not logged in
    get "/skip"
    assert last_response.redirect?, "Did not redirect to login page!"
    assert_equal 'http://example.org/user/login', last_response.location, 'Was not sent to the login page!' 
    
    # logged in as a non super admin or Maintainer should fail
    post '/user/login', { :login => @user.login, :password => @pwd }
    get "/skip"
    assert_equal 'http://example.org/unauthorized', last_response.location, "Was not sent to the unauthorized page! user: #{@user.inspect}" 
    post '/user/logout'

    # logged in as a Manager/Maintainer
    post '/user/login', {:login => @mgr.login, :password => @pwd}
    get '/skip'
    assert last_response.ok?, 'Unable to access the Skip Check page as a manager!'
    post '/user/logout'

    # logged in as a super admin
    post '/user/login', {:login => @adm.login, :password => @pwd}
    get '/skip'
    assert last_response.ok?, 'Unable to access the Skip Check page as a super admin!'
    post '/user/logout'
  end

# ---------------------------------------------------------------
# Test page post
# ---------------------------------------------------------------
  def test_post_skip
    # not logged in
    post "/skip", {:domain => 'www.google.com'}
    assert last_response.redirect?, "Did not redirect to login page!"
    assert_equal 'http://example.org/user/login', last_response.location, 'Was not sent to the login page!' 
    
    # logged in as a non super admin or Maintainer should fail
    post '/user/login', { :login => @user.login, :password => @pwd }
    # attempt to create a new skip check when not a maintainer or super admin
    post "/skip", {:domain => 'www.google.com'}
    assert_equal 'http://example.org/unauthorized', last_response.location, 'Was not sent to the unauthorized page!' 
    post '/user/logout'

    # logged in as a Manager/Maintainer
    post '/user/login', {:login => @mgr.login, :password => @pwd}
    # create a new skip check
    post "/skip", {:domain => 'www.google.com'}
    assert last_response.ok?, 'Unable to create a new Skip Check!'
    assert !SkipCheck.first(:domain => 'www.google.com').nil?, 'Could not load the newly created skip check!'
    post '/user/logout'

    # logged in as a super admin
    post '/user/login', {:login => @adm.login, :password => @pwd}
    # create a new skip check
    post "/skip", {:domain => 'www.cdlib.org'}
    assert last_response.ok?, 'Unable to create a new Skip Check!'
    assert !SkipCheck.first(:domain => 'www.cdlib.org').nil?, 'Could not load the newly created skip check!'
    # attempt to create a skip check for a domain that already exists
    post "/skip", {:domain => 'yahoo.com'}
    assert_equal 500, last_response.status, 'Was able to create a skip check for an already existing domain!'
    # attempt to create a skip check for a domain that already exists
    post "/skip", {:domain => 'www.yahoo.com/1'}
    assert_equal 500, last_response.status, 'Was able to create a skip check for an already existing domain!'

    post '/user/logout'
  end
  
# ---------------------------------------------------------------
# Test page delete
# ---------------------------------------------------------------
  def test_delete_skip
    grp = Group.new(:id => 'OTHER', :name => 'Other Group')
    grp.save
    SkipCheck.new(:domain => 'www.google.com', :created_at => Time.now, :group => grp.id).save

    # not logged in
    get "/skip"
    assert last_response.redirect?, "Did not redirect to login page!"
    assert_equal 'http://example.org/user/login', last_response.location, 'Was not sent to the login page!' 
    
    # logged in as a non super admin or Maintainer should fail
    post '/user/login', { :login => @user.login, :password => @pwd }
    # attempt to delete a skip check when not a group maintainer or super admin
    delete "/skip", {:domain => 'www.yahoo.com'}
    assert_equal 'http://example.org/unauthorized', last_response.location, 'Was not sent to the unauthorized page!' 
    post '/user/logout'

    # logged in as a Manager/Maintainer
    post '/user/login', {:login => @mgr.login, :password => @pwd}
    # delete a skip check
    delete "/skip", {:domain => 'www.yahoo.com'}
    assert last_response.ok?, "Unable to delete the Skip Check as a manager! #{last_response.status}"
    # attempt to delete another group's skip check
    delete "/skip", {:domain => 'www.google.com'}
    assert_equal 401, last_response.status, 'Was able to delete another groups skip check!'
    post '/user/logout'

    # logged in as a super admin
    post '/user/login', {:login => @adm.login, :password => @pwd}
    # delete a skip check
    delete "/skip", {:domain => 'www.huffingtonpost.com'}
    assert last_response.ok?, 'Unable to delete the Skip Check as a super admin!'
    # attempt to delete a skip check that doesn't exist
    delete "/skip", {:domain => 'www.cdlib.org'}
    assert last_response.not_found?, 'Was able to delete a Skip Check that doesnt exist!'
    post '/user/logout'
  end
  
end
require_relative '../test_helper'

class PidManageApp < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    PidApp
  end

  def setup
    Pid.flush!
    @group = Group.new(:id => 'UCLA', :name => 'test_group')
    @user = User.new(:handle => 'test_user', :name => 'Test User')
    @group.users << @user
    @group.save
  end
  
# ---------------------------------------------------------------
# Search page tests
# ---------------------------------------------------------------
  def test_search_empty_params
    get '/link/search'
    assert last_response.body.empty?
  end
  
  def test_search_by_url_pass
    Pid.mint(:url => 'http://www.google.com', :username => @user.handle, :change_category => 'User_Entered')
    Pid.mint(:url => 'http://maps.google.com', :username => @user.handle, :change_category => 'User_Entered')
    Pid.mint(:url => 'http://cdlib.org', :username => @user.handle, :change_category => 'User_Entered')
    Pid.mint(:url => 'http://www.ebay.com', :username => @user.handle, :change_category => 'User_Entered')
    
    # wilcard match 2 urls
    get '/link/search', {:url => 'google.com'}
    assert last_response.ok?
    assert last_response.body.include?('to-do')  #make sure it returned 2 google PIDs
    
    # wilcard match 1 url
    get '/link/search', {:url => 'www.ebay.com'}
    assert last_response.ok?
    assert last_response.body.include?('to-do')  #make sure it returned 1 PID for ebay
    
    # wilcard match ALL urls
    get '/link/search', {:url => 'http://'}
    assert last_response.ok?
    assert last_response.body.include?('to-do')  #make sure it returned 4 PIDs
    
    # specific url match
    get '/link/search', {:url => 'http://cdlib.org'}
    assert last_response.ok?
    assert last_response.body.include?('to-do')  #make sure it returned the cdlib PID
    
    # wilcard match with over 50 hits returns only 50 PIDs
    urls = *(1..60)
    urls.each{ |url| Pid.mint(:url => 'http://www.wikipedia.org/#{url}', :username => @user.handle, :change_category => 'User_Entered')}
    
    get '/link/search', {:url => 'wikipedia.org/'}
    assert last_response.ok?
    assert last_response.body.include?('to-do')  #make sure there are only 50 results
  end
  
  def test_search_by_url_404
    get '/link/search', {:url => 'http://owa.cdlib.org/'}
    assert_equal 404, last_response
  end
  
  def test_search_by_pid_range_404
    get '/link/search', {:min_pid => 50, :max_pid => 75}
    assert_equal 404, last_response
  end
  
  def test_search_by_pid_range_pass
    urls = *(1..20)
    urls.each{ |url| Pid.mint(:url => 'http://www.wikipedia.org/#{url}', :username => @user.handle, :change_category => 'User_Entered')}
    
    get '/link/search', {:min_pid => 5, :max_pid => 12}
    assert last_response.ok?
    assert last_response.body.include?('to-do') #make sure it returned 7 PIDs
  end
  
=begin
  def test_search_by_minter
    Pid.mint(:url => 'http://cdlib.org', :username => @user.handle, :change_category => 'User_Entered')
    
    get 'link/search', {:username => @user.handle}
    assert last_response.ok?
    assert last_response.body.include?('to-do') #make sure it returned the PID we minted
  end
  
  def test_search_by_minter_404
    get 'link/search', {:username => @user.handle}
    assert_equal 404, last_response
  end
  
  def test_search_by_maintainer
    Pid.mint(:url => 'http://cdlib.org', :username => @user.handle, :change_category => 'User_Entered', :maintainer => @group.id)
    
    get 'link/search', {:maintainer => @group.id}
    assert last_response.ok?
  end
  
  def test_search_by_maintainer_404
    get 'link/search', {:maintainer => @group.id}
    assert_equal 404, last_response
  end
  
=end

# ---------------------------------------------------------------
# Show PID tests
# ---------------------------------------------------------------
  def test_show_pid
    link = Pid.mint(:url => 'http://cdlib.org', :username => @user.handle, :change_category => 'User_Entered')
    get '/link/1'
    assert last_response.ok?
  end
   
  def test_show_404_pid
    link = Pid.mint(:url => 'http://cdlib.org', :username => @user.handle, :change_category => 'User_Entered')
    get '/link/1234'
    assert !last_response.ok?
  end
  
# ---------------------------------------------------------------
# Mint PID tests
# ---------------------------------------------------------------
  def test_new_pid
    get '/link/new'
    assert_equal 200, last_response.status
  end
  
  def test_create_pid
    post '/link', { :url => 'http://cdlib.org' }
    assert_equal 302, last_response.status
  end
  
  def test_create_multiple_pids
    post '/link', { :url => "http://cdlib.org\nhttp://google.com" }
    assert_equal 200, last_response.status
  end
  
  def test_create_pid_bad_data
    post '/link', { :url => 'cdlib.org' }
    assert_equal 400, last_response.status
  end
  
  def test_create_multiple_pids_good_and_bad_data
    post '/link', { :url => "cdlib.org\nhttp://google.com" }
    assert_equal 400, last_response.status
  end
  
  def test_create_multiple_pids_all_bad_data
    post '/link', { :url => "cdlib.org\ngoogle.com" }
    assert_equal 400, last_response.status
  end
end
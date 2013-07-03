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
    post '/link/search'
    
    assert last_response.ok?
    assert last_response.body.include?('"no_results"')
  end
  
  def test_search_by_url_pass
    Pid.mint(:url => 'http://www.testme.abc', :username => @user.handle, :change_category => 'User_Entered')
    Pid.mint(:url => 'http://maps.testme.abc', :username => @user.handle, :change_category => 'User_Entered')
    Pid.mint(:url => 'http://test.cdlib.abc', :username => @user.handle, :change_category => 'User_Entered')
    Pid.mint(:url => 'http://www.testit.abc', :username => @user.handle, :change_category => 'User_Entered')
    
    # Warning, any tests to count the number of <tr> returned should account for the <th> row!
    
    # wilcard match 2 urls
    post '/link/search', {:url => 'testme.abc'}
    assert last_response.ok?
    assert_equal 3, last_response.body.gsub("<tr>").count  #make sure it returned 2 google PIDs
    
    # wilcard match 1 url
    post '/link/search', {:url => 'www.testit.abc'}
    assert last_response.ok?
    assert_equal 2, last_response.body.gsub('<tr>').count  #make sure it returned 1 PID for ebay
    
    # wilcard match ALL urls
    post '/link/search', {:url => '.abc'}
    assert last_response.ok?
    assert_equal 5, last_response.body.gsub('<tr>').count  #make sure it returned 4 PIDs
    
    # specific url match
    post '/link/search', {:url => 'http://test.cdlib.abc'}
    assert last_response.ok?
    assert_equal 2, last_response.body.gsub('<tr>').count  #make sure it returned the cdlib PID
    
    # wilcard match with over 100 hits returns only 100 PIDs
    urls = *(1..110)
    urls.each{ |url| Pid.mint(:url => 'http://www.testwikipedia.org/#{url}', :username => @user.handle, :change_category => 'User_Entered')}
    
    post '/link/search', {:url => 'testwikipedia.org/'}
    assert last_response.ok?
    assert_equal 101, last_response.body.gsub('<tr>').count  #make sure there are only 50 results
  end
  
  def test_search_by_url_404
    post '/link/search', {:url => 'http://owa.cdlib.org/'}
    assert last_response.body.include?('"no_results"')
  end

=begin
  def test_search_by_pid_range_no_match
    post '/link/search', {:min_pid => 50, :max_pid => 75}
    assert last_response.ok?
    assert last_response.body.include?('"no_results"')
  end
  
  def test_search_by_pid_range_pass
    urls = *(1..20)
    urls.each{ |url| Pid.mint(:url => 'http://www.wikipedia.org/#{url}', :username => @user.handle, :change_category => 'User_Entered')}
    
    post '/link/search', {:min_pid => 5, :max_pid => 12}
    assert last_response.ok?
    assert last_response.body.include?('to-do') #make sure it returned 7 PIDs
  end
=end

=begin
  def test_search_by_minter
    Pid.mint(:url => 'http://cdlib.org', :username => @user.handle, :change_category => 'User_Entered')
    
    post 'link/search', {:username => @user.handle}
    assert last_response.ok?
    assert last_response.body.include?('to-do') #make sure it returned the PID we minted
  end
  
  def test_search_by_minter_no_match
    post 'link/search', {:username => @user.handle}
    assert last_response.ok?
    assert last_response.body.include?('"no_results"')
  end
  
  def test_search_by_maintainer
    Pid.mint(:url => 'http://cdlib.org', :username => @user.handle, :change_category => 'User_Entered', :maintainer => @group.id)
    
    post 'link/search', {:maintainer => @group.id}
    assert last_response.ok?
  end
  
  def test_search_by_maintainer_no_match
    post 'link/search', {:maintainer => @group.id}
    assert last_response.ok?
    assert last_response.body.include?('"no_results"')
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
    post '/link', { :new_urls => 'http://cdlib.org' }
    assert_equal 302, last_response.status
  end
  
  def test_create_multiple_pids
    post '/link', { :new_urls => "http://cdlib.org\nhttp://google.com" }
    assert_equal 302, last_response.status
  end
  
  def test_create_pid_bad_data
    post '/link', { :new_urls => 'cdlib.org' }
    assert_equal 400, last_response.status
  end
  
  def test_create_multiple_pids_good_and_bad_data
    post '/link', { :new_urls => "cdlib.org\nhttp://google.com" }
    assert_equal 400, last_response.status
  end
  
  def test_create_multiple_pids_all_bad_data
    post '/link', { :new_urls => "cdlib.org\ngoogle.com" }
    assert_equal 400, last_response.status
  end
end
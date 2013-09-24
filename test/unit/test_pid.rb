require_relative '../test_helper'

class TestPid < Test::Unit::TestCase
  
  def setup
    Pid.flush!
    @pwd = 'secret'
    @group = Group.new(:id => 'UCLA', :name => 'test_group')
    @user = User.new(:login => 'test_user', :name => 'Test User', :email => 'test@example.org', :password => @pwd)
    @group.users << @user
    @group.save
      
    @params = {:url => 'http://www.cdlibs.org',
               :username => @user.login, 
               :notes => 'Test', 
               :change_category => 'Test', 
               :group => @group}
               
    @shorty = Shortcake.new('pid', {:host => PidApp::APP_CONFIG['redis_host'], :port => PidApp::APP_CONFIG['redis_port']})
  end

# -----------------------------------------------------------------------------------------------    
  def test_create_new
    # Test a valid mint operation
    pid = Pid.mint(@params)
    assert_equal 1, pid.id, "Was unable to save a PID with a valid URL!"
    assert_equal 1, pid.pid_versions.count, "The new Pid does not have 1 version!"
    assert_equal pid.url, @shorty.get(pid.id), "The Redis server does not have a record for the PID!"
      
    # Test an invalid URL 
    @params[:url] = 'www.cdlibs.org'
    assert_raise(PidException){ Pid.mint(@params) }
  end
  
# -----------------------------------------------------------------------------------------------  
  def test_modify
    link = Pid.mint(@params)
      
    # Test a valid revision
    link.revise(:url => 'http://www.google.com', :group => @group, :notes => 'Test', :deactivated => false)
    link.reload
    assert_equal 'http://www.google.com', link.url
      
    # Test an invalid URL
    assert_raise(PidException){ link.revise(:url => 'www.google.com', :group => @group, :notes => 'Test', :deactivated => false) }
  end
  
# -----------------------------------------------------------------------------------------------  
  def test_get_pids
    # Mint 2 valid URLs and one with an invalid URL
    Pid.mint(@params)
    @params[:url] = 'http://www.google.com'
    Pid.mint(@params)
    @params[:url] = 'www.cdlibs.org'
    assert_raise(PidException){ Pid.mint(@params) }
      
    # Make sure that only the 2 valid PIDs were created
    assert_equal 2, Pid.all.size
  end
  
# -----------------------------------------------------------------------------------------------  
  def test_search_pids
    # Mint 2 valid URLs and one with an invalid URL
    Pid.mint(@params)
    @params[:url] = 'http://www.google.com'
    Pid.mint(@params)
    
    # Try a few search options
    assert_equal 1, Pid.count(:url => 'http://www.google.com')
    assert_equal 2, Pid.count(:url.like => 'http://%')
    assert_equal 2, Pid.count(:username => @user.login)
    assert_equal 0, Pid.count(:url.like => 'yahoo.com' )
  end
  
# -----------------------------------------------------------------------------------------------  
  def test_reconcile_servers_when_true
    # Mint 2 valid URLs and one with an invalid URL
    Pid.mint(@params)
    @params[:url] = 'http://www.google.com'
    Pid.mint(@params)
    
    # Make sure the Redis server has the same number of Pids as the MySql DB
    assert_equal true, Pid.reconcile
    
    # Flush the Redis server
    Pid.flush_shortcake!
    assert_equal false, Pid.reconcile
  end
    
end
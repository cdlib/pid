require_relative '../test_helper'

class TestPid < Test::Unit::TestCase
  
    def setup
      Pid.flush!
      @group = Group.new(:id => 'UCLA', :name => 'test_group')
      @user = User.new(:login => 'test_user', :name => 'Test User', :email => 'test@example.org')
      @group.users << @user
      @group.save
    end
    
    def test_create_new
      note = 'test pid'
      url = 'http://cdlib.org'
      link = Pid.mint(:url => url, :username => @user.login, :notes => note, :change_category => 'User_Entered', :group => @group)
      assert_equal 1, link.id 
    end
    
    def test_modify
      url = 'http://cdlib.org'
      url_revised = 'http://uclibs.org'
      link = Pid.mint(:url => url, :username => @user.login, :change_category => 'User_Entered', :group => @group)
      link.revise(:url => url_revised, :username => @user.login, :notes => 'revising link', :change_category => 'User_Entered')
      link.reload
      assert_equal url_revised, link.url
    end
    
    def test_get_pids
      url = 'http://cdlib.org'
      url_second = 'http://uclibs.org'
      assert_equal true, !Pid.mint(:url => url, :username => @user.login, :change_category => 'User_Entered', :group => @group).nil?
      assert_equal true, !Pid.mint(:url => url_second, :username => @user.login, :change_category => 'User_Entered', :group => @group).nil?
      assert_equal 2, Pid.all.size
    end
    
    def test_search_pids
      url = 'http://cdlib.org'
      url_second = 'http://uclibs.org'
      assert_equal true, !Pid.mint(:url => url, :username => @user.login, :change_category => 'User_Entered', :group => @group).nil?
      assert_equal true, !Pid.mint(:url => url_second, :username => @user.login, :change_category => 'User_Entered', :group => @group).nil?
      assert_equal 1, Pid.count(:url => url)
      assert_equal 2, Pid.count(:url.like => 'http://%')
      assert_equal 2, Pid.count(:username => @user.login)
    end
    
    def test_reconcile_servers_when_true
      url = 'http://cdlib.org'
      url_second = 'http://uclibs.org'
      assert_equal true, !Pid.mint(:url => url, :username => @user.login, :change_category => 'User_Entered', :group => @group).nil?
      assert_equal true, !Pid.mint(:url => url_second, :username => @user.login, :change_category => 'User_Entered', :group => @group).nil?
      assert_equal true, Pid.reconcile
    end
    
    def test_reconcile_servers_when_false
      url = 'http://cdlib.org'
      url_second = 'http://uclibs.org'
      assert_equal true, !Pid.mint(:url => url, :username => @user.login, :change_category => 'User_Entered', :group => @group).nil?
      assert_equal true, !Pid.mint(:url => url_second, :username => @user.login, :change_category => 'User_Entered', :group => @group).nil?
      Pid.flush_shortcake!
      assert_equal false, Pid.reconcile
    end
end
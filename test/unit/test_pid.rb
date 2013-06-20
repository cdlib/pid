ENV['DATABASE_URL'] = "sqlite3://#{File.absolute_path(File.dirname(__FILE__))}/test.db"
require_relative '../test_helper'
require 'test/unit'
require 'pid_models'
require 'fakeredis' # mock redis used by shortcake

class TestPid < Test::Unit::TestCase
  
    def setup
      Pid.flush!
      @group = Group.new(:name => 'test_group')
      @user = User.new(:name => 'test_user')
      @group.users << @user
      @group.save
    end
    
    def test_create_new
      note = 'test pid'
      url = 'http://cdlib.org'
      link = Pid.mint(:url => url, :username => @user.name, :notes => note)
      assert_equal 1, link.id 
    end
    
    def test_modify
      url = 'http://cdlib.org'
      url_revised = 'http://uclibs.org'
      link = Pid.mint(:url => url, :username => @user.name)
      link.revise(:url => url_revised, :username => @user.name, :notes => 'revising link')
      link.reload
      assert_equal url_revised, link.url
    end
    
    def test_get_pids
      url = 'http://cdlib.org'
      url_second = 'http://uclibs.org'
      assert_equal true, !Pid.mint(:url => url, :username => @user.name).nil?
      assert_equal true, !Pid.mint(:url => url_second, :username => @user.name).nil?
      assert_equal 2, Pid.all.size
    end
    
    def test_search_pids
      url = 'http://cdlib.org'
      url_second = 'http://uclibs.org'
      assert_equal true, !Pid.mint(:url => url, :username => @user.name).nil?
      assert_equal true, !Pid.mint(:url => url_second, :username => @user.name).nil?
      assert_equal 1, Pid.count(:url => url)
      assert_equal 2, Pid.count(:url.like => 'http://%')
      assert_equal 2, Pid.count(:username => @user.name)
    end
    
    def test_reconcile_servers_when_true
      url = 'http://cdlib.org'
      url_second = 'http://uclibs.org'
      assert_equal true, !Pid.mint(:url => url, :username => @user.name).nil?
      assert_equal true, !Pid.mint(:url => url_second, :username => @user.name).nil?
      assert_equal true, Pid.reconcile
    end
    
    def test_reconcile_servers_when_false
      url = 'http://cdlib.org'
      url_second = 'http://uclibs.org'
      assert_equal true, !Pid.mint(:url => url, :username => @user.name).nil?
      assert_equal true, !Pid.mint(:url => url_second, :username => @user.name).nil?
      Pid.flush_shortcake!
      assert_equal false, Pid.reconcile
    end
end
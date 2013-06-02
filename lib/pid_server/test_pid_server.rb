ENV['DATABASE_URL'] = "sqlite3://#{Dir.pwd}/test.db"
require 'test/unit'
require './pid_server'
require 'fakeredis' # mock redis used by shortcake

class TestPidServer < Test::Unit::TestCase
  
    def setup
      @pid_server = PidServer.new
      @pid_server.flushall
      @group = Group.new(:name => 'test_group')
      @user = User.new(:name => 'test_user')
      @group.users << @user
      @group.save
    end
    
    def test_create_new
      note = 'test pid'
      url = 'http://cdlib.org'
      link = @pid_server.mint(url, @user, note)
      assert_equal 1, link.pid 
    end
    
    def test_modify
      url = 'http://cdlib.org'
      url_revised = 'http://uclibs.org'
      link = @pid_server.mint(url, @user, '')
      assert_equal 1, link.pid
      @pid_server.revise(link.pid, url_revised, @user, 'revising link')
      link.reload
      assert_equal url_revised, link.url
    end
    
    def test_get_pids
      url = 'http://cdlib.org'
      url_second = 'http://uclibs.org'
      assert_equal true, !@pid_server.mint(url, @user, '').nil?
      assert_equal true, !@pid_server.mint(url_second, @user, '').nil?
      assert_equal ['1', '2'], @pid_server.pids
    end
    
end
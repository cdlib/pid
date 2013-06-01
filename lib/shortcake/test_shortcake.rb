require 'test/unit'
require './shortcake'
require 'fakeredis'

class TestShortkut < Test::Unit::TestCase
  
    def setup
      @shorty = Shortcake.new('pid', {:host => "localhost", :port => 7777})
      @shorty.flushall
    end
    
    def test_create_new
      pid = '1234'
      url = 'http://cdlib.org'
      assert_equal true, @shorty.create(pid, url)
      assert_equal url, @shorty.get(pid)
    end
    
    def test_create_new_when_exists
      pid = '1234'
      url = 'http://cdlib.org'
      @shorty.create(pid, url)
      assert_raise(CodeExists) { @shorty.create(pid, url) }
    end
    
    def test_update
      pid = '1234'
      url = 'http://cdlib.org'
      url_update = 'http://uclibs.org'
      assert_equal true, @shorty.create(pid, url)
      assert_equal true, @shorty.update(pid, url_update)
      assert_equal url_update, @shorty.get(pid)
    end
    
    def test_update_when_does_not_exist
      pid = '1234'
      url_update = 'http://uclibs.org'
      assert_raise(CodeDoesNotExists) { @shorty.update(pid, url_update) }
    end
    
    def test_create_or_update_when_create
      pid = '1234'
      url = 'http://cdlib.org'
      assert_equal true, @shorty.create_or_update(pid, url)
      assert_equal url, @shorty.get(pid)
    end
    
    def test_create_or_update_when_update
      pid = '1234'
      url = 'http://cdlib.org'
      url_update = 'http://uclibs.org'
      assert_equal true, @shorty.create(pid, url)
      assert_equal true, @shorty.create_or_update(pid, url_update)
      assert_equal url_update, @shorty.get(pid)
    end
    
    def test_init_must_pass_valid_namespace
      assert_raise(ValidNSRequired) { Shortcake.new('', {:host => "localhost", :port => 9999}) }
      assert_raise(ValidNSRequired) { Shortcake.new('iamtoolongtobeanamespace', {:host => "localhost", :port => 9999}) }
      assert_raise(ValidNSRequired) { Shortcake.new('I_Have_Bad_Characters', {:host => "localhost", :port => 9999}) }
      assert_equal true, true
    end
    
    def test_create_must_use_valid_code
      url = 'http://cdlib.org'
      assert_raise(ValidCodeRequired) { @shorty.create('', url) }
      assert_raise(ValidCodeRequired) { @shorty.create('iamtoolongtobeacode', url) }
      assert_raise(ValidCodeRequired) { @shorty.create('bad_symbols', url) }
      assert_equal true, true
    end
    
    def test_create_must_use_valid_url
      pid = '1234'
      assert_raise(ValidURLRequired) { @shorty.create(pid, 'i am not a url') }
    end
    
    def test_get_all_codes_in_namespace
      pid = '1234'
      url = 'http://cdlib.org'
      pid_second = '5342'
      url_second = 'http://uclibs.org'
      assert_equal true, @shorty.create(pid, url)
      assert_equal true, @shorty.create(pid_second, url_second)
      assert_equal [pid, pid_second], @shorty.codes
    end
    
end
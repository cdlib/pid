$LOAD_PATH.unshift(File.absolute_path(File.dirname(__FILE__)))
require_relative '../../test/test_helper'

class TestShortcake < Minitest::Test
  
    def setup
      @shorty = Shortcake.new('pid', { host: PidApp::APP_CONFIG['redis_host'], port: PidApp::APP_CONFIG['redis_port'] })
      @shorty.flushall!
    end
    
    def test_create_new
      id = '1234'
      url = 'http://cdlib.org'
      assert_equal true, @shorty.create(id, url)
      assert_equal url, @shorty.get(id)
    end
    
    def test_create_new_when_exists
      id = '1234'
      url = 'http://cdlib.org'
      @shorty.create(id, url)
      assert_raises(CodeExists) { @shorty.create(id, url) }
    end
    
    def test_update
      id = '1234'
      url = 'http://cdlib.org'
      url_update = 'http://uclibs.org'
      assert_equal true, @shorty.create(id, url)
      assert_equal true, @shorty.update(id, url_update)
      assert_equal url_update, @shorty.get(id)
    end
    
    def test_update_when_does_not_exist
      id = '1234'
      url_update = 'http://uclibs.org'
      assert_raises(CodeDoesNotExist) { @shorty.update(id, url_update) }
    end
    
    def test_create_or_update_when_create
      id = '1234'
      url = 'http://cdlib.org'
      assert_equal true, @shorty.create_or_update(id, url)
      assert_equal url, @shorty.get(id)
    end
    
    def test_create_or_update_when_update
      id = '1234'
      url = 'http://cdlib.org'
      url_update = 'http://uclibs.org'
      assert_equal true, @shorty.create(id, url)
      assert_equal true, @shorty.create_or_update(id, url_update)
      assert_equal url_update, @shorty.get(id)
    end
    
    def test_delete_when_does_not_exist
      id = '1234'
      url_update = 'http://uclibs.org'
      assert_raises(CodeDoesNotExist) { @shorty.update(id, url_update) }
    end
    
    def test_delete
      id = '1234'
      url = 'http://cdlib.org'
      assert_equal true, @shorty.create_or_update(id, url)
      assert_equal url, @shorty.get(id)
      
      assert_equal true, @shorty.delete(id), 'Unable to delete the record from Redis!'
      assert_nil @shorty.get(id), 'The record still exists in Redis!'
    end
    
    def test_init_must_pass_valid_namespace
      assert_raises(ValidNSRequired) { Shortcake.new('', { host: "localhost", port: 9999 }) }
      assert_raises(ValidNSRequired) { Shortcake.new('iamtoolongtobeanamespace', { host: "localhost", port: 9999 }) }
      assert_raises(ValidNSRequired) { Shortcake.new('I_Have_Bad_Characters', { host: "localhost", port: 9999}) }
      assert_equal true, true
    end
    
    def test_create_must_use_valid_code
      url = 'http://cdlib.org'
      assert_raises(ValidCodeRequired) { @shorty.create('', url) }
      assert_raises(ValidCodeRequired) { @shorty.create('iamtoolongtobeacode', url) }
      assert_raises(ValidCodeRequired) { @shorty.create('bad_symbols', url) }
      assert_equal true, true
    end
    
    def test_create_must_use_valid_url
      id = '1234'
      assert_raises(ValidURLRequired) { @shorty.create(id, 'i am not a url') }
    end
    
    def test_get_all_codes_in_namespace
      id = '1234'
      url = 'http://cdlib.org'
      id_second = '5342'
      url_second = 'http://uclibs.org'
      assert_equal true, @shorty.create(id, url)
      assert_equal true, @shorty.create(id_second, url_second)
      assert_equal [id, id_second], @shorty.codes
    end
    
end
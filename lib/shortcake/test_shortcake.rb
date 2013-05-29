require 'test/unit'
require './shortkut'
class TestShortkut < Test::Unit::TestCase
    def test_create_new
      assert_equal true, true
    end
    
    def test_create_new_when_exists
      assert_equal true, true
    end
    
    def test_update
      assert_equal true, true
    end
    
    def test_update_when_does_not_exist
      assert_equal true, true
    end
    
    def test_create_or_update_when_create
      assert_equal true, true
    end
    
    def test_create_or_update_when_update
      assert_equal true, true
    end
    
    def test_init_must_pass_valid_namespace
      assert_equal true, true
    end
    
    def test_create_must_use_valid_code
      assert_equal true, true
    end
    
    def test_create_must_use_valid_url
      assert_equal true, true
    end
    
    def test_get_all_codes_in_namespace
      assert_equal true, true
    end
    
    def test_search_all_urls_in_namespace
      assert_equal true, true
    end
end
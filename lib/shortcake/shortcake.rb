require 'redis'
require 'uri'

class Shortcake
  VALID_NS = Regexp.compile(/^[a-z0-9]{1,5}$/)
  VALID_CODE = Regexp.compile(/^[a-zA-Z0-9]{1,10}$/)
  
  def initialize(namespace, redis_config)
    @redis = Redis.new(redis_config)
    raise ValidNSRequired if !namespace.kind_of?(String) || !namespace.match(VALID_NS)
    @ns = namespace
  end
  
  def create(shortcode, url)
    create_url(shortcode, url, true)
  end
  
  def update(shortcode, url)
    raise CodeDoesNotExists if !@redis.exists("sc:#{@ns}:codes:#{shortcode}")
    create_url(shortcode, url, true)
  end
  
  def create_or_update(shortcode, url)
    create_url(shortcode, url, true)
  end
  
  def get(shortcode)
    @redis.get("sc:#{@ns}:codes:#{shortcode}")
  end
  
  def redis
    @redis
  end
  
  def codes
    @redis.keys("sc:#{@ns}:codes:*").map { |key| key[13,key.length] }
  end
  
  private 
  def create_url(shortcode, url, override=false)
    raise ValidCodeRequired if !shortcode.kind_of?(String) || !shortcode.match(VALID_CODE)
    raise ValidURLRequired if (url =~ URI::regexp).nil?
    @redis.multi do |multi|
      exists = @redis.exists(shortcode)
      raise CodeExists if !override && exists
      @redis.set("sc:#{@ns}:codes:#{shortcode}", url)
    end
  end
end

class ValidNSRequired < StandardError; end
class ValidURLRequired < StandardError; end
class ValidCodeRequired < StandardError; end
class CodeExists < StandardError; end
class CodeDoesNotExists < StandardError; end
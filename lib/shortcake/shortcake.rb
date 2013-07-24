require 'redis'
require 'uri'

class Shortcake
  VALID_NS = Regexp.compile(/^[a-z0-9]{1,5}$/)
  VALID_CODE = Regexp.compile(/^[a-zA-Z0-9]{1,12}$/)
  
  def initialize(namespace, redis_config)
    @redis = Redis.new(redis_config)
    raise ValidNSRequired if !namespace.kind_of?(String) || !namespace.match(VALID_NS)
    @ns = namespace
  end
  
  def create(shortcode, url)
    create_url(shortcode, url, false)
  end
  
  def update(shortcode, url)
    raise CodeDoesNotExist if !@redis.exists("sc:#{@ns}:codes:#{shortcode}")
    create_url(shortcode, url, true)
  end
  
  def create_or_update(shortcode, url)
    create_url(shortcode, url, true)
  end
  
  def get(shortcode)
    @redis.get("sc:#{@ns}:codes:#{shortcode}")
  end
  
  def delete(shortcode)
    raise CodeDoesNotExist if !@redis.exists("sc:#{@ns}:codes:#{shortcode}")
    deleted = @redis.del("sc:#{@ns}:codes:#{shortcode}")
    return (deleted >= 1) ? true : false
  end
  
  def flushall!
    @redis.flushall
  end
  
  def dbsize
    @redis.dbsize
  end
  
  def codes
    @redis.keys("sc:#{@ns}:codes:*").map { |key| key[@ns.length+10, key.length] }
  end
  
  private 
  def create_url(shortcode, url, override=false)
    raise ValidCodeRequired if !shortcode.kind_of?(String) || !shortcode.match(VALID_CODE)
    raise ValidURLRequired if (url =~ URI::regexp).nil?
    raise CodeExists if !override && @redis.exists("sc:#{@ns}:codes:#{shortcode}")
    @redis.multi do |multi|
      @redis.set("sc:#{@ns}:codes:#{shortcode}", url)
    end
    return true
  end
end

class ValidNSRequired < StandardError; end
class ValidURLRequired < StandardError; end
class ValidCodeRequired < StandardError; end
class CodeExists < StandardError; end
class CodeDoesNotExist < StandardError; end
require 'redis'
require 'uri'
require 'json'

class Shortcake
  VALID_NS = Regexp.compile(/^[a-z0-9]{1,5}$/)
  VALID_CODE = Regexp.compile(/^[a-zA-Z0-9]{1,12}$/)
  
  #TODO: Use the one on app.rb!!
  #URI_REGEX = /[fh]t{1,2}ps?:\/\/[a-zA-Z0-9\-_\.]+(:[0-9]+)?(\/[a-zA-Z0-9\/`~!@#\$%\^&\*\(\)\-_=\+{}\[\]\|\\;:'",<\.>\?])?/
  
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
    
    # Remove the PID association from its old URL!
    clear_reverse_reference(shortcode, url)
    
    create_url(shortcode, url, true)
  end
  
  def create_or_update(shortcode, url)
    create_url(shortcode, url, true)
  end
  
  def get(shortcode)
    ret = @redis.get("sc:#{@ns}:codes:#{shortcode}")
    
    ret = @redis.get("url:#{@ns}:codes:#{shortcode}") if ret.nil?
    
    ret
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
    #@redis.dbsize
    @redis.keys("sc:#{@ns}:codes:*").size
  end
  
  def codes
    @redis.keys("sc:#{@ns}:codes:*").map { |key| key[@ns.length+10, key.length] }
  end
  
private 
  def create_url(shortcode, url, override=false)
    existing = @redis.get("sc:#{@ns}:codes:#{shortcode}")
    
    raise ValidCodeRequired if !shortcode.kind_of?(String) || !shortcode.match(VALID_CODE)
    #raise ValidURLRequired if (url =~ URI::regexp).nil?
    raise ValidURLRequired if (url =~ PidApp::URI_REGEX).nil?
    raise CodeExists if !override && !existing.nil?
    
    # If the code already exists, detach it from its old URL
    if !existing.nil?
      clear_reverse_reference(shortcode, existing)
    end
    
    @redis.multi do |multi|
      @redis.set("sc:#{@ns}:codes:#{shortcode}", url)
    end
    
    # associate the code with its url
    save_reverse_references(shortcode, url)
    
    return true
  end
  
  def clear_reverse_reference(shortcode, url)
    old = @redis.get("url:#{@ns}:codes:#{url}")
    pids = []
    
    # If the URL is associated wit hthe PID, remove the reference
    if !old.nil?  
      pids = JSON.parse(@redis.get("url:#{@ns}:codes:#{url}"))
      pids.delete(shortcode)
      
      # If that was the only PID associated with that URL, remove the record
      if pids.empty?
        @redis.multi do |multi|
          @redis.del("url:#{@ns}:codes:#{url}")
        end
        
      # Otherwise update the record 
      else
        @redis.multi do |multi|
          @redis.set("url:#{@ns}:codes:#{url}", pids.to_json)
        end
      end
    end
  end
  
  def save_reverse_references(shortcode, url)
    old = @redis.get("url:#{@ns}:codes:#{url}")
    pids = []

    pids = JSON.parse(@redis.get("url:#{@ns}:codes:#{url}")) unless old.nil?
    
    pids << shortcode

    @redis.multi do |multi|
      @redis.set("url:#{@ns}:codes:#{url}", pids.to_json)
    end
  end
end

class ValidNSRequired < StandardError; end
class ValidURLRequired < StandardError; end
class ValidCodeRequired < StandardError; end
class CodeExists < StandardError; end
class CodeDoesNotExist < StandardError; end
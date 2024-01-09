require 'redis'
require 'uri'
require 'json'

class Shortcake
  VALID_NS = Regexp.compile(/^[a-z0-9]{1,5}$/)
  VALID_CODE = Regexp.compile(/^[a-zA-Z0-9]{1,12}$/)
  
  def initialize(namespace, redis_config)
    @redis = Redis.new({ **redis_config, ssl: PidApp::APP_CONFIG['redis_use_ssl'] == 'true' } )
    raise ValidNSRequired if !namespace.kind_of?(String) || !namespace.match(VALID_NS)
    @ns = namespace
  end
  
  def create(shortcode, url)
    create_url(shortcode, url, false)
  end
  
  def update(shortcode, url)
    raise CodeDoesNotExist if @redis.get("sc:#{@ns}:codes:#{shortcode}").nil?
    
    create_url(shortcode, url, true)
  end
  
  def create_or_update(shortcode, url)
    create_url(shortcode, url, true)
  end
  
  def get(shortcode)
    ret = @redis.get("sc:#{@ns}:codes:#{shortcode}")
  
    # Potential UTF-8 encoding commented oout for now
    # ret = CGI::unescape(ret) unless ret.nil?
    
    # puts "returning: #{ret}"
    # puts "alternate: #{CGI.unescape(ret)}"
    # puts "cgi -> uri #{URI.escape(CGI.unescape(ret)).downcase}"
    
    # URI.escape(CGI.unescape(ret)).downcase
    ret
  end
  
  def delete(shortcode)
    raise CodeDoesNotExist if @redis.get("sc:#{@ns}:codes:#{shortcode}").nil?
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
    
    @redis.set("sc:#{@ns}:codes:#{shortcode}", url)
    # @redis.multi do |multi|

#    target = url.clone
#    protocol = target.scan(/[fh]t{1,2}ps?:\/\//)
    
    #target = protocol[0] + CGI.escape(target.gsub(protocol[0], ''))
    
#    domain_start = protocol[0].length
#    domain_len = target.gsub(protocol[0], '').index(/\//)
#    path_start = domain_start + domain_len
#    path_len = url.length - path_start
    
#    domain = url.slice(domain_start, domain_len)
#    path = url.slice(path_start, path_len)
    
# puts "protocol: #{protocol[0]}"
# puts "domain is: #{domain}"     

#    target = protocol[0] + domain + CGI.escape(path)

#puts "path is: #{path}"
     
    #target = protocol[0]
    #target += (domain == CGI.escape(domain)) ? domain : CGI.escape(domain)
    #target += (path == CGI.escape(path)) ? path : CGI.escape(path)

#puts "#{domain} == #{CGI.unescape(CGI.escape(domain))}"    
#puts "#{path} == #{CGI.escape(path)}"

#puts "original #{url}"
#puts "using #{target}"
         
    #uri = URI.parse(target) 
    
#puts "host: #{uri.host}, path: #{uri.path}, query: #{uri.query}, fragment: #{uri.fragment}"

#puts "translates to: #{CGI.unescape(target)}"
#puts "Without this work: #{CGI.unescape(CGI.escape(url))}"

#puts "-----------------------------------------------"    
    
    #3465456 / 0
    
    #uri = new URI(url)
    #uri.host = URI.escape(uri.host) unless uri.host == URI.unescape(uri.host)
    #uri.path = URI.escape(uri.path) unless uri.path == URI.unescape(uri.path)
    #uri.query = URI.escape(uri.query) unless uri.query == URI.unescape(uri.query)
    #uri.fragment = URI.escape(uri.fragment) unless uri.fragment == URI.unescape(uri.fragment)


    # TODO: Need to figure out how to use IDN-RUBY to escape URLs. Storing the below example URL
    # and then redirecting to it again does not work in Firefox or Safari. 
    # Tried escaping with URI and CGI but both do not work
    # http://例え.テスト/%E3%83%A1%E3%82%A4%E3%83%B3%E3%83%9A%E3%83%BC%E3%82%B8
    # Chrome converts to IDN: http://xn--r8jz45g.xn--zckzah/%E3%83%A1%E3%82%A4%E3%83%B3%E3%83%9A%E3%83%BC%E3%82%B8
    # which seems to work in all browsers

    # @redis.set("sc:#{@ns}:codes:#{shortcode}", url)
      
      #@redis.set("sc:#{@ns}:codes:#{shortcode}", CGI.escape(url))

      # Escape the URL unless it is already escaped! - commented out for now
      #target = (url == CGI.unescape(url)) ? url : CGI::escape(url)
      #@redis.set("sc:#{@ns}:codes:#{shortcode}", target)
      
    # end
    
    return true
  end
end

class ValidNSRequired < StandardError; end
class ValidURLRequired < StandardError; end
class ValidCodeRequired < StandardError; end
class CodeExists < StandardError; end
class CodeDoesNotExist < StandardError; end
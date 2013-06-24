require_relative '../test_helper'

class PidRedirectApp < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    PidApp
  end
  
  def setup
    @shorty = Shortcake.new('short', {:host => "localhost", :port => 6379})
    @shorty.flushall!
  end
  
  def test_pid_redirect
    @shorty.create_or_update('1', 'http://google.com')
    get '/1'
    assert_equal 'http://google.com', last_response.location
    assert_equal 302, last_response.status
  end
  
  def test_pid_partial_redirect
    @shorty.create_or_update('1', 'http://google.com')
    get '/1/search?q=elmo'
    assert_equal 'http://google.com/search?q=elmo', last_response.location
    assert_equal 302, last_response.status
  end
  
  def test_pid_no_redirect
    get '/1234'
    assert_equal 404, last_response.status
  end
  
  def test_pid_no_partial_redirect
    get '/1/search?q=elmo'
    assert_equal 404, last_response.status
  end
  
end
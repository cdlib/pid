require 'test/unit'
require 'rack/test'
require './pid_app'
require 'fakeredis' # mock redis used by shortcake


ENV['RACK_ENV'] = 'test'

class PidApp < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_it_loads
    get '/'
    assert last_response.ok?
    assert_equal 'Success', last_response.body
  end
end
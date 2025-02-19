require 'bundler/setup'
Bundler.require(:default, ENV['RACK_ENV'].to_sym)

require 'rack/protection'
use Rack::Protection
use Rack::HostAuthorization, :hosts => [ENV['APP_HOST']]

require_relative 'app'
run PidApp

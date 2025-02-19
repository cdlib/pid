require 'bundler/setup'
Bundler.require(:default, ENV['RACK_ENV'].to_sym)

require 'rack/protection'
use Rack::Protection::HostAuthorization, :host => [ENV['APP_HOST']]

require_relative 'app'
run PidApp

require 'rack'
require 'bundler/setup'
Bundler.require(:default, ENV['RACK_ENV'].to_sym)
use Rack::HostAuthorization, nil
require_relative 'app'
run PidApp

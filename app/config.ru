require 'rubygems'
require 'bundler'
Bundler.require(:default, ENV['RACK_ENV'].to_sym)
root = ::File.dirname(__FILE__)
require ::File.join( root, 'app' )
run PidApp.new
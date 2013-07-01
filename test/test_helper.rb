ENV['RACK_ENV'] = 'test'
ENV['DATABASE_URL'] = "sqlite3://#{File.absolute_path(File.dirname(__FILE__))}/test.db"
$LOAD_PATH.unshift(File.absolute_path(File.join(File.dirname(__FILE__), '../')))
require 'rubygems'
require 'bundler'
Bundler.require(:default, ENV['RACK_ENV'].to_sym)
require 'test/unit'
require 'app'
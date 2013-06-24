ENV['RACK_ENV'] = 'test'
ENV['DATABASE_URL'] = "sqlite3://#{File.absolute_path(File.dirname(__FILE__))}/test.db"
$LOAD_PATH.unshift(File.absolute_path(File.join(File.dirname(__FILE__), '../models/')))
$LOAD_PATH.unshift(File.absolute_path(File.join(File.dirname(__FILE__), '../lib/shortcake')))
$LOAD_PATH.unshift(File.absolute_path(File.join(File.dirname(__FILE__), '../')))
require 'test/unit'
require 'rack/test'
require 'fakeredis'
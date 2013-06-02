$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + '/lib/pid_server'))
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + '/lib/shortcake'))
require 'rubygems'
require 'sinatra'
require 'data_mapper'
require 'dm-transactions'
require 'pid_server'


pid_server = PidServer.new

get '/' do
  "Success"
end
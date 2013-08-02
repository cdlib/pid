ENV['RACK_ENV'] = 'test'
ENV['DATABASE_URL'] = "sqlite::memory:"
$LOAD_PATH.unshift(File.absolute_path(File.join(File.dirname(__FILE__), '../')))
require 'rubygems'
require 'bundler'
Bundler.require(:default, ENV['RACK_ENV'].to_sym)
require 'test/unit'
require 'app'

require 'capybara/dsl'
require 'capybara/poltergeist'

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, {
        :js_errors => true,
        :run_server => false
    })
end

Capybara.configure do |config|
  config.default_driver = :poltergeist
end

Capybara.javascript_driver = :poltergeist
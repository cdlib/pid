require 'rubygems'
require 'sinatra'
require 'data_mapper'
require 'dm-transactions'
require './lib/shortcake/shortcake'

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/dev.db")

class User
  include DataMapper::Resource
  belongs_to :group
  
  property :id, Serial, :key => true
  property :name, String
  property :description, String, :length => 250
end

class Group
  include DataMapper::Resource
  has n, :users
  
  property :id, Serial, :key => true
  property :name, String
  property :description, String, :length => 250
end

class Link
  include DataMapper::Resource
  belongs_to :group
  has n, :link_versions
  
  property :pid, Serial, :key => true
  property :url, String
  property :username, String
  property :created_at, DateTime
  property :modified_at, DateTime
  property :notes, String, :length => 250
end

class LinkVersion
  include DataMapper::Resource
  belongs_to :link
  belongs_to :group
    
  property :id, Serial, :key => true
  property :url, String
  property :username, String
  property :created_at, DateTime
  property :notes, String, :length => 250
end

DataMapper.finalize.auto_upgrade!

class PidServer
  def initialize
    @shorty = Shortcake.new('pid', {:host => "localhost", :port => 6379})
  end
  
  def pids
    @shorty.codes
  end
  
  def get(id)
    @shorty.get(id)
  end
  
  def mint(url,user,notes)
    Link.transaction do |t|
      begin
        now = Time.now
        params = {:url => url, :username => user.name, :group => user.group, :notes => notes, :created_at => now}
        link = Link.new(params.merge(:modified_at => now))
        link.link_versions << LinkVersion.new(params)
        link.save && @shorty.create(link.pid.to_s, url) && link
      rescue DataObjects::Error
        t.rollback
      end
    end
  end
  
  def revise(pid,url,user,notes)
    Link.transaction do |t|
      begin
        link = Link.get(pid)
        if link
          now = Time.now
          params = {:url => url, :username => user.name, :group => user.group, :notes => notes, :created_at => now}
          link.update(params.merge(:modified_at => now))
          link.link_versions << LinkVersion.new(params)
          link.save && @shorty.update(link.pid.to_s, url) && link
        end
      rescue DataObjects::Error
        t.rollback
      end
    end
  end
end

pid_server = PidServer.new
get '/' do
  group = Group.new(:name => 'thegroup')
  puts group.inspect
  user = User.new(:name => 'ed')
  puts user.inspect
  group.users << user
  group.save
  link = pid_server.mint('http://google.com', user, 'testing')
  puts pid_server.revise(link.pid, 'http://facebook.com', user, 'testing 2').inspect
  pid_server.pids.each do |pid|
    puts pid
    puts pid_server.get(pid)
  end
  "Success"
  # erb :index
end
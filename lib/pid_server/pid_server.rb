require 'data_mapper'
require 'dm-transactions'
require 'shortcake'

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
  has n, :links, :through => :group_link
  
  property :id, Serial, :key => true
  property :name, String
  property :description, String, :length => 250
end

class Link
  include DataMapper::Resource
  has n, :link_versions
  has n, :groups, :through => :group_link
  
  property :pid, Serial, :key => true
  property :url, String
  property :username, String
  property :created_at, DateTime
  property :modified_at, DateTime
  property :notes, String, :length => 250
end

class GroupLink
  include DataMapper::Resource
  belongs_to :group
  belongs_to :link
  property :id, Serial, :key => true
end

class LinkVersion
  include DataMapper::Resource
  belongs_to :link
    
  property :id, Serial, :key => true
  property :url, String
  property :username, String
  property :created_at, DateTime
  property :notes, String, :length => 250
end

DataMapper::Model.raise_on_save_failure = true
DataMapper.finalize.auto_upgrade!

class PidServer
  def initialize
    @shorty = Shortcake.new('pid', {:host => "localhost", :port => 6379})
  end
  
  def flushall
    @shorty.flushall
    DataMapper.auto_migrate!(:default)
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
        params = {:url => url, :username => user.name, :notes => notes, :created_at => now}
        link = Link.new(params.merge(:modified_at => now))
        link.link_versions << LinkVersion.new(params)
        link.groups << user.group
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
          params = {:url => url, :username => user.name,:notes => notes, :created_at => now}
          link.update(params.merge(:modified_at => now))
          link.link_versions << LinkVersion.new(params)
          link.groups << user.group
          link.save && @shorty.update(link.pid.to_s, url) && link
        end
      rescue DataObjects::Error
        t.rollback
      end
    end
  end
end
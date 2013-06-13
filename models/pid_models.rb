require 'data_mapper'
require 'dm-transactions'
require_relative '../lib/shortcake/shortcake'

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
  has n, :pids, :through => :group_pid
  
  property :id, Serial, :key => true
  property :name, String
  property :description, String, :length => 250
end

class Pid
  include DataMapper::Resource
  has n, :pid_versions
  has n, :groups, :through => :group_pid
  
  property :id, Serial, :key => true
  property :url, String
  property :username, String
  property :created_at, DateTime
  property :modified_at, DateTime
  property :notes, String, :length => 250
  
  @@shorty = Shortcake.new('pid', {:host => "localhost", :port => 6379})
  
  def revise(params)
    params = self.attributes.clone.merge({:notes => ''}.merge(params))
    params.delete(:modified_at)
    params.delete(:created_at)
    Pid.create_or_update(params)
  end
  
  def self.create_or_update(params)
    Pid.transaction do |t|
      begin
        now = Time.now
        groups = params.delete(:groups)
        if params[:id]
          pid = Pid.get(params[:id])
          return nil if pid.nil?
          params.delete(:id)
          pid.attributes = params.merge(:modified_at => now)
        else
          pid = Pid.new(params.merge(:created_at => now, :modified_at => now))
        end
        pid.pid_versions << PidVersion.new(params.merge(:created_at => now))
        pid.groups = group if groups
        pid.save && @@shorty.create_or_update(pid.id.to_s, params[:url]) && pid
      rescue Exception => e
        t.rollback
        raise e
      end
    end
  end
  
  def self.mint(params)
    Pid.create_or_update(params)
  end

  def self.flush!
    Pid.flush_shortcake!
    Pid.flush_db!
  end
  
  def self.flush_shortcake!
    @@shorty.flushall
  end
  
  def self.flush_db!
    DataMapper.auto_migrate!(:default)
  end
  
  def self.reconcile
    Pid.count == @@shorty.dbsize
  end
end

class GroupPid
  include DataMapper::Resource
  belongs_to :group
  belongs_to :pid
  property :id, Serial, :key => true
end

class PidVersion
  include DataMapper::Resource
  belongs_to :pid
    
  property :id, Serial, :key => true
  property :url, String
  property :username, String
  property :created_at, DateTime
  property :notes, String, :length => 250
end

DataMapper::Model.raise_on_save_failure = true
DataMapper.finalize.auto_upgrade!
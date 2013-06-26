class PidVersion
  include DataMapper::Resource
  belongs_to :pid
    
  property :id, Serial, :key => true
  property :deactivated, Boolean, :required  => true
  property :change_category, String, :length => 20, :format => /[a-zA-Z\_]+/, :required => true
  property :url, String, :length => 2000, :format => :url, :required => true
  property :username, String, :length => 20, :format => /[a-z]{3,20}/, :required => true
  property :created_at, DateTime, :required => true
  property :notes, String, :length => 250
end

class Pid
  include DataMapper::Resource
  has n, :pid_versions
  has n, :maintainers
  has n, :groups, :through => :maintainers
  
  #property :id, Serial, :key => true
  property :id, String, :key => true, :format => /^[a-zA-Z0-9]{1,12}$/, :length => 50,
  	:messages => {
  		:format => "The PID must be between 1 and 12 characters long."
  	}
  	  
  property :deactivated, Boolean, :default  => false, :index => true
  property :change_category, String, :length => 20, :format => /[a-zA-Z\_]+/, :required => true,
    :messages => {
      :presence  => "A change category is required.",
      :format    => "Categories must be no more than 20 alpha characters, underscores accepted."
    }
  property :url, String, :length => 2000, :format => :url, :required => true,
    :messages => {
      :presence  => "A url is required.",
      :format    => "Must be valid URL of under 2000 characters."
    }
  property :username, String, :length => 20, :format => /[a-z]{3,20}/, :required => true
  property :created_at, DateTime, :required => true, :index => true
  property :modified_at, DateTime, :required => true, :index => true
  property :notes, String, :length => 250
  
  # restriction for saving, updating. ensure handling through create_or_update for shortcake syncing
  attr_accessor :mutable
  
  @@shorty = Shortcake.new('pid', {:host => "localhost", :port => 6379})
  
  def revise(params)
    params = self.attributes.clone.merge({:notes => nil}.merge(params))
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
        	
        	#If the user is seed we will need to create the pid
        	if pid.nil? && params[:username] == 'seed_user'

        		pid = Pid.new(params)	

        	elsif pid.nil?
          	return nil
          end
          
          params.delete(:id)
          pid.attributes = params.merge(:modified_at => now)
        else
          pid = Pid.new(params.merge(:created_at => now, :modified_at => now))
        end

        pid.pid_versions << PidVersion.new(params.merge(:created_at => now, :deactivated => pid.deactivated))
        pid.groups = groups if groups
        
        pid.mutable = true
        
puts "Saving #{pid.id} => #{pid.url}"        
        
        pid.save && @@shorty.create_or_update(pid.id.to_s, params[:url]) && pid
        
      rescue Exception => e
        t.rollback
        
puts "error in pid.rb"        
pid.errors.each do |err|
	puts err
end         
        
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
    @@shorty.flushall!
  end
  
  def self.flush_db!
    DataMapper.auto_migrate!(:default)
  end
  
  def self.reconcile
    Pid.count == @@shorty.dbsize
  end
  
  before :save do |post|
    if self.deactivated == true && self.attribute_dirty?(:url)
      throw :halt
    end
    # restriction for saving, updating. ensure handling through create_or_update for shortcake syncing
    unless self.mutable
      throw :halt
    end
  end
  
  before :update do |post|
    # restriction for saving, updating. ensure handling through create_or_update for shortcake syncing
    unless self.mutable
      throw :halt
    end
  end
  
  before :destroy do |post|
    # pids are immutable
    throw :halt
  end
end

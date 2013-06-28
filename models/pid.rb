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
  
  property :id, Serial, :key => true
  	  
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
  property :username, String, :length => 20, :format => /[a-z]{3,20}/, :required => true,
  	:messages => {
  		:presence	=> "A username is required.",
  		:format		=> "Username should be between 3 to 20 alpha characters."
  	}
  property :created_at, DateTime, :required => true, :index => true
  property :modified_at, DateTime, :required => true, :index => true
  property :notes, String, :length => 250
  
  # restriction for saving, updating. ensure handling through create_or_update for shortcake syncing
  attr_accessor :mutable
  
  @@shorty = Shortcake.new('pid', {:host => "localhost", :port => 6379})
  
  def revise(params)
  	
  	#If we're seeding its ok for the modified_at to come through as a param
  	unless params[:is_seed]

    	params = self.attributes.clone.merge({:notes => nil}.merge(params))
    	params.delete(:modified_at)
    	params.delete(:created_at)
    else

    	params = self.attributes.clone.merge(params)
    end
    
    Pid.create_or_update(params)
  end
  
  
  def self.create_or_update(params)
  	is_seed = params[:is_seed]
  	params.delete(:is_seed)	
	
    Pid.transaction do |t|
      begin
        now = Time.now
        #groups = params.delete(:groups)

				#If an ID was specified then we're updating or inserting (if this is the DB seed)
        if params[:id]					
        	pid = Pid.get(params[:id])
        	
        	#If we're seeding the DB and the ID doesn't exist
        	if pid.nil? && is_seed
        		pid = Pid.new(params)	

					#If we're not seeding and the ID is missing exit
        	elsif pid.nil?
          	return nil
          	
          #Otherwise we're updating so set the modified_at to now
          else
          	pid.attributes = params.merge(:modified_at => (is_seed) ? params[:modified_at] : now)
          end
        
        #Otherwise we're creating a new PID
        else
          pid = Pid.new(params.merge(:created_at => now, :modified_at => now))
          params = params.merge(pid.attributes.clone.merge(params))
        end

				#Save the version
				params.delete_if{|k, v| ['id', 'modified_at', 'groups'].include?(k.to_s)}
				if is_seed
				
					pid.pid_versions << PidVersion.new(params.merge(:created_at => pid.modified_at))
				else
        	pid.pid_versions << PidVersion.new(params.merge(:created_at => now, :deactivated => pid.deactivated))
        end
        	
        #pid.groups = groups if groups
        
        pid.mutable = true
        
        pid.save && @@shorty.create_or_update(pid.id.to_s, params[:url]) && pid
        
      rescue Exception => e
      puts pid.inspect
      
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

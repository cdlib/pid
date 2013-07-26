# Represents a historical snapshot of a PID, a new PidVersion record is created everytime a change is made to a PID
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

# Represents a Persistent Identifier (PID).
class Pid
  include DataMapper::Resource
  has n, :pid_versions
  belongs_to :group
  
  property :id, Serial, :key => true

  property :deactivated, Boolean, :default  => false, :index => true
  property :change_category, String, :length => 20, :format => /[a-zA-Z\_]+/, :required => true,
    :messages => {
      :presence  => 'A change category is required.',
      :format    => 'Categories must be no more than 20 alpha characters, underscores accepted.'
    }
    
  # To-Do - The DataMapper :url :format validation doesn't like http://[IP Address]:[Port]
  property :url, String, :length => 2000, :format => :url, :required => true,
    :messages => {
      :presence  => 'A url is required.',
      :format    => 'Must be valid URL of under 2000 characters.'
    }
  property :username, String, :length => 50, :format => /[a-z\s]{3,50}/, :required => true,
    :messages => {
      :presence => 'A username is required.',
      :format => 'Username should be between 3 to 20 alpha characters.'
    }
  property :created_at, DateTime, :required => true, :index => true
  property :modified_at, DateTime, :required => true, :index => true
  property :notes, String, :length => 250
  
  # restriction for saving, updating. ensure handling through create_or_update for shortcake syncing
  attr_accessor :mutable
  
  # establish a connection to the REDIS database
  @@shorty = Shortcake.new('pid', {:host => 'localhost', :port => 6379})

  # ---------------------------------------------------------------
  # Make a revision/change to the PID
  # ---------------------------------------------------------------
  def revise(params)  
    begin
      #If we're seeding its ok for the modified_at to come through as a param
      unless params[:is_seed]
        params = self.attributes.clone.merge({:notes => nil}.merge(params))
        params.delete(:modified_at)
        params.delete(:created_at)
      else
        params = self.attributes.clone.merge(params)
      end
      
      Pid.create_or_update(params)
      
    rescue Exception => e
      raise e
    end
  end
  
  # ------------------------------------------------------------------------------
  # Save the PID, this method will determine whether we're inserting/updating
  # ------------------------------------------------------------------------------
  def self.create_or_update(params)
    is_seed = (params[:is_seed].nil?) ? false : params[:is_seed]
    params.delete(:is_seed)
    
    # FIXME - DataMapper :format => :url allows the url to exclude the protocol (e.g. http://)
    #         our regex on the screens does not though, we need to either add it if its missing
    #         here or allow it on the screens (see the regex on pid_controller.rb)
    #
    #         It also does not allow FTP !
    
    
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
            revise_params = {}
            [:change_category, :url, :username, :notes, :deactivated].each { |key| revise_params[key] = params[key] }
            
            pid.attributes = revise_params.merge(:modified_at => (is_seed) ? params[:modified_at] : now)
          end
        
        #Otherwise we're creating a new PID
        else
          pid = Pid.new(params.merge(:created_at => now, :modified_at => now))
          params = params.merge(pid.attributes.clone.merge(params))
        end

        #Save the version
        version_params = {:pid => pid}
        [:change_category, :url, :username, :notes, :deactivated].each { |key| version_params[key] = params[key] }

        ver = nil
        if is_seed
          ver = PidVersion.new(version_params.merge(:created_at => pid.modified_at))
        else
          ver = PidVersion.new(version_params.merge(:created_at => now, :deactivated => pid.deactivated))
        end
          
        # If the version has errors that are not just Pid must not be blank (happens with new PID record) raise an exception
        if (ver.errors.count == 1 && ver.errors.first != "Pid must not be blank") || ver.errors.count > 1
          raise Exception.new("Failure saving version: #{ver.errors.full_messages.join("\n")}")
        else
          pid.pid_versions << ver
        end

        pid.mutable = true
        
        if pid.valid?
          pid.save
          
          # If the pid is inactive, remove it from Redis, otherwise add/update it
          if pid.deactivated
            @@shorty.delete(pid.id.to_s)
          else
            @@shorty.create_or_update(pid.id.to_s, params[:url])
          end
          
        else
          raise Exception.new("Failure saving Pid: #{pid.errors.full_messages.join("\n")}")
        end
        
        pid
        
      rescue DataMapper::SaveFailureError => e
        #no rollback needed, nothing saved
        t.rollback        
        raise e
      rescue Exception => e
        t.rollback       
        raise e
      end
    end
  end
  
  # --------------------------------------------------------------------------------------
  # Methods that prevent the DataMapper object from performing its normal CRUD operations
  # --------------------------------------------------------------------------------------
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
  
    #TODO - Should they be able to save anyway? What if they want to reactivate?
  
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

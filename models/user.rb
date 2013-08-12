require 'digest/sha1'
class User
  include DataMapper::Resource
  belongs_to :group, :required => false
  #has 1, :maintainer, :required => false
  
  property :id, Serial, :key => true
  property :login, String, :length => 20, :format => /[a-z]{3,20}+/, :unique => true, :required => true,
      :messages => {
        :presence  => 'A username is required.',
        :is_unique => 'We already have that username.',
        :format    => 'Usernames must be a combination of 3-20 lowercase letters.'
      }
  property :name, String, :length => 100, :format => /\w+/, :required => true,
      :messages => {
        :presence  => 'A name is required.',
        :format    => 'Names must be under 100 characters without symbols.'
      }
  property :email, String, :length => 100, :format => :email_address, :required => true,
           :messages => {
           :format => 'The value you entered does not a valid email address!'
      }
  property :affiliation, String, :length => 100, :format => /\.*/, :required => false,
           :messages => {
           :format	=> 'Affiliations must be less than 100 characters long!'
      }
  property :active, Boolean, :default => true
  property :locked, Boolean, :default => false
  property :locked_timer, Integer, :required => false
  property :failed_login_attempts, Integer, :default => 0
  property :last_login, Date, :required => false
  property :reset_code, String, :required => false
  property :reset_timer, Integer, :required => false
  property :super, Boolean, :default => false
  property :hashed_password, String
  property :salt, String
  property :created_at, DateTime

  attr_accessor :password

  def active?
    self.active
  end
  
  def password=(pass)
    @password = pass
    self.salt = User.random_string(10) unless self.salt
    self.hashed_password = User.encrypt(@password, self.salt)
  end

  def self.encrypt(pass, salt)
    Digest::SHA1.hexdigest(pass.to_s + salt.to_s)
  end

  def self.authenticate(login, pass)    
    u = User.first(:login => login)
    return nil if u.nil?
    
    # If the user account has a locked timer set
    if !u.locked_timer.nil?
      
      # If the locked timer hasn't expired (see /conf/security.yml for the number of minutes)
      if u.locked_timer >= Time.now.to_i
        return nil
        
        # Otherwise the locked timer has expired so lets clear the user's record and unlock it
      else
        u.locked_timer = nil
        u.locked = false
        u.failed_login_attempts = 0
        u.save
      end
      
    # Otherwise, if the user's account is locked then lockouts are indefinite and require admin intervention
    else
      return nil if u.locked
    end
    return nil if !u.active
    
    return u if User.encrypt(pass, u.salt) == u.hashed_password
      nil
  end
  
  def self.random_string(len)
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    str = ""
    1.upto(len) { |i| str << chars[rand(chars.size-1)] }
    return str
  end
  
  # A password reset creates a random reset key and starts a timer. An email gets sent to the user that contains a url. That url contains
  # the reset key in its query string. If the key matches and the reset page is opened within the timeframe defined in the security.yml file,
  # the user is able to reset their password without logging in.
  def reset_password()
    self.reset_code = User.random_string(20)
    self.reset_timer = Time.now.to_i
  end

  def self.active
    User.all(:active => true)
  end
  
  def self.deactivated
    User.all(:active => false)
  end
  
  def self.flush!
    DataMapper.auto_migrate!
  end
end
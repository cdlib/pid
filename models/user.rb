require 'digest/sha1'
class User
  include DataMapper::Resource
  belongs_to :group
  
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
  property :email, String, :length => 100, :format => :email_address, :required => false,
           :messages => {
           :format => 'The value you entered does not a valid email address!'
      }
  property :affiliation, String, :length => 100, :format => /\.*/, :required => false,
           :messages => {
           :format	=> 'Affiliations must be less than 100 characters long!'
      }
  property :password_hint, String, :length => 50, :format => /\.*/, :required => false,
           :messages => {
           :format => 'The password hint must be less than 50 characters long!'
      }
  property :active, Boolean, :default => true
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
    Digest::SHA1.hexdigest(pass + salt)
  end

  def self.authenticate(login, pass)
    u = User.first(:login => login)
    return nil if u.nil?
    return u if User.encrypt(pass, u.salt) == u.hashed_password
      nil
  end
  
  def self.random_string(len)
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    str = ""
    1.upto(len) { |i| str << chars[rand(chars.size-1)] }
    return str
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
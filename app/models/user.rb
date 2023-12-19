# -----------------------------------------------------------------------------------------------   
# Represents a user of the system
#
# If super is set to true the user is a super admin and has full access to everything (no group restrictions)
# If readonly is set to true the user will only be able to search for and view PIDs (no group restrictions)
# -----------------------------------------------------------------------------------------------   
require 'uri'
require 'digest/sha1'

class User < ActiveRecord::Base
  belongs_to :group, optional: true

  validates :login, presence: true, length: { maximum: 20 }, uniqueness: true, format: { with: /\A[a-z]{3,20}+\z/ } # If uniqueness: true is added then it won't reach the database and raise RecordNotUnique.
  validates :name, presence: true, length: { maximum: 100 }, format: { with: /\w+/ }
  validates :email, presence: true, length: { maximum: 100 }, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :affiliation, format: { with: /\A.*\z/ }
  validates :active, inclusion: { in: [true, false] } # TODO: Default value true db migration?
  validates :locked, inclusion: { in: [true, false] } # TODO: Default value false db migration?
  validates :failed_login_attempts, presence: true, numericality: { only_integer: true } # TODO: Default value 0 db migration?
  validates :reset_attempts, numericality: { only_integer: true } # TODO: Default value 0 db migration?
  validates :super, inclusion: { in: [true, false] }
  validates :hashed_password, presence: true
  validates :salt, presence: true
  validates :host, length: { maximum: 30 }
  validates :read_only, inclusion: { in: [true, false] } # TODO: Default value false db migration?

  attr_accessor :password

  scope :active, -> { where(active: true) }
  scope :deactivated, -> { where(active: false) }

  def active?
    active
  end

  def password=(pass)
    @password = pass
    self.salt = User.random_string(10) unless salt
    self.hashed_password = User.encrypt(@password, salt)
  end

  def self.encrypt(pass, salt)
    Digest::SHA1.hexdigest(pass.to_s + salt.to_s)
  end

  def self.authenticate(login, pass)
    user = User.find_by(login: login)
    
    return nil if user.nil?

    if user.locked_timer && user.locked_timer >= Time.now.to_i
      return nil
    elsif user.locked_timer
      user.update(locked_timer: nil, locked: false, failed_login_attempts: 0)
    elsif user.locked
      return nil
    end

    return nil unless user.active

    return user if User.encrypt(pass, user.salt) == user.hashed_password

    nil
  end

  def self.random_string(len)
    chars = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
    str = ''
    1.upto(len) { str << chars.sample }
    str
  end

  def reset_password
    self.reset_code = User.random_string(20)
    self.reset_timer = Time.now.to_i
    self.reset_attempts += 1
  end

  def self.flush!
    connection.execute('DELETE FROM users')
  end
end

# -----------------------------------------------------------------------------------------------   
# Represents a Collection of Users
# -----------------------------------------------------------------------------------------------   
class Group < ActiveRecord::Base
  has_many :users, dependent: :restrict_with_exception
  has_many :maintainers, dependent: :restrict_with_exception
  has_many :pids, dependent: :restrict_with_exception

  validates :id, length: { maximum: 10 }, uniqueness: true, format: { with: /[A-Z]+/ }
  validates :name, presence: true, length: { maximum: 200 }, format: { with: /\w+/ }
  validates :description, length: { maximum: 250 }
  validates :host, length: { maximum: 30 }

  def self.flush!
    self.destroy_all
  end
end

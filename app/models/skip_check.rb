# -----------------------------------------------------------------------------------------------   
# Represents a domain that we will ignore when doing url validation for PIDs
#
# This list is managed by super admins and Group Maintainers/Managers
# -----------------------------------------------------------------------------------------------
class SkipCheck < ActiveRecord::Base
  validates :domain, presence: true,  uniqueness: true # If uniqueness: true is added then it won't reach the database and raise RecordNotUnique.
  validates :created_at, presence: true
  validates :group, length: { maximum: 10 }, format: { with: /[A-Z]+/ }
  
  def self.flush!
    connection.execute('DELETE FROM skip_checks')
  end
end

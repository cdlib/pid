# -----------------------------------------------------------------------------------------------   
# Represents a record from a scheduled report that looks for duplicate URLs
#
# These reports are executed by a scheduled cron job on the server
# -----------------------------------------------------------------------------------------------   
class DuplicateUrlReport < ActiveRecord::Base
  has_many :pid, dependent: :nullify
  
  validates :other_pids, presence: true
  
  def self.flush!
    self.destroy_all
  end
end

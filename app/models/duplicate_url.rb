# -----------------------------------------------------------------------------------------------   
# Represents a record from a scheduled report that looks for duplicate URLs
#
# These reports are executed by a scheduled cron job on the server
# -----------------------------------------------------------------------------------------------   
class DuplicateUrlReport < ActiveRecord::Base
  belongs_to :pid, optional: true
  
  validates :other_pids, presence: true
  
  def self.flush!
    connection.execute('DELETE FROM duplicate_url_reports')
  end
end

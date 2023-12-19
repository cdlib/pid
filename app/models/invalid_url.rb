# -----------------------------------------------------------------------------------------------   
# Represents the output of a scheduled report record that checks to see if the URL target returns > HTTP 200 
#
# These reports are executed by a scheduled cron job on the server
# -----------------------------------------------------------------------------------------------   
class InvalidUrlReport < ActiveRecord::Base
  belongs_to :pid, optional: true

  validates :http_code, presence: true
  
  def self.flush!
    connection.execute('DELETE FROM invalid_url_reports')
  end
end

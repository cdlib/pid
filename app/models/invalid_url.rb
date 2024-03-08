# -----------------------------------------------------------------------------------------------   
# Represents the output of a scheduled report record that checks to see if the URL target returns > HTTP 200 
#
# These reports are executed by a scheduled cron job on the server
# -----------------------------------------------------------------------------------------------   
class InvalidUrlReport < ActiveRecord::Base
  belongs_to :pid

  validates :http_code, presence: true
  
  def self.flush!
    self.destroy_all
  end
end

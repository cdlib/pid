# -----------------------------------------------------------------------------------------------   
# Represents the output of a scheduled report record that checks to see if the URL target returns > HTTP 200 
#
# These reports are executed by a scheduled cron job on the server
# -----------------------------------------------------------------------------------------------   
class InvalidUrlReport
  include DataMapper::Resource
  
  property :id, Serial, :key => true
  property :http_code, Integer, :required => true
  property :last_checked, Time, :required => false
  belongs_to :pid, :required => false
  
  def self.flush!
    DataMapper.auto_migrate!(:default)
  end
end

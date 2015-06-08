# -----------------------------------------------------------------------------------------------   
# Represents a record from a scheduled report that looks for duplicate URLs
#
# These reports are executed by a scheduled cron job on the server
# -----------------------------------------------------------------------------------------------   
class DuplicateUrlReport
  include DataMapper::Resource
  
  property :id, Serial, :key => true
  property :other_pids, Text, :required => true
  property :last_checked, Time, :required => false
  belongs_to :pid, :required => false  
 
  def self.flush!
    DataMapper.auto_migrate!(:default)
  end
end

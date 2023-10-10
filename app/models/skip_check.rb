# -----------------------------------------------------------------------------------------------   
# Represents a domain that we will ignore when doing url validation for PIDs
#
# This list is managed by super admins and Group Maintainers/Managers
# -----------------------------------------------------------------------------------------------   
class SkipCheck
  include DataMapper::Resource
  
  property :domain, String, :key => true
  property :created_at, DateTime, :required => true, :index => true
  property :group, String, :length => 10, :format => /[A-Z]+/
    
  def self.flush!
    DataMapper.auto_migrate!(:default)
  end
end
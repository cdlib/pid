# -----------------------------------------------------------------------------------------------   
# A.K.A. Group Manager
#
# Represents the association between a Group and a User indicating that the user manages that group
#
# A manager/maintainer of a group can add and edit user accounts
#
# A user may manage/maintain multiple groups and groups may have multiple managers/maintainers
# -----------------------------------------------------------------------------------------------   
class Maintainer
  include DataMapper::Resource
  belongs_to :group, :key => true
  belongs_to :user, :key => true
  
  def self.flush!
    DataMapper.auto_migrate!(:default)
  end
end
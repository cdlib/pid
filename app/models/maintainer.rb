# -----------------------------------------------------------------------------------------------   
# A.K.A. Group Manager
#
# Represents the association between a Group and a User indicating that the user manages that group
#
# A manager/maintainer of a group can add and edit user accounts
#
# A user may manage/maintain multiple groups and groups may have multiple managers/maintainers
# -----------------------------------------------------------------------------------------------   
class Maintainer < ActiveRecord::Base
  belongs_to :group
  belongs_to :user
  
  def self.flush!
    connection.execute('DELETE FROM maintainers')
  end
end

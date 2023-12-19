# -----------------------------------------------------------------------------------------------   
# A.K.A. Interested Party
#
# An association between a PID and a Group that ensures that the Group is notified of changes made to the PID
#
# This association is established when a user attempts to mint a new PID for a URL that already exists in a 
# PID owned by another group.
#
# The owners of the original PID see a note on the show_pid page that lets them know that another group is
# watching the PID
#
# Users can search for PIDs that they have an interest in
# -----------------------------------------------------------------------------------------------   
class Interested < ActiveRecord::Base
  belongs_to :group
  belongs_to :pid

  validates :group_id, presence: true, uniqueness: { scope: :pid_id }
  validates :pid_id, presence: true

  validate :not_owner

  # Do not allow the owner of a PID to also be an interested party
  def not_owner
    errors.add(:base, 'Owner of PID cannot be an interested party') if pid&.group == group
  end

  def self.flush!
    connection.execute('DELETE FROM interesteds')
  end
end

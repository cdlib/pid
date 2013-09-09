class Interested
  include DataMapper::Resource
  belongs_to :group, :key => true
  belongs_to :pid, :key => true

  validates_with_method :not_owner

  # Do not allow the owner of a PID to also be an interested party
  def not_owner
    self.pid.group != self.group
  end

  def self.flush!
    DataMapper.auto_migrate!(:default)
  end
end
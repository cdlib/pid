class Interested
  include DataMapper::Resource
  belongs_to :group, :key => true
  belongs_to :pid, :key => true
  
  def self.flush!
    DataMapper.auto_migrate!(:default)
  end
end
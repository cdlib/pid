class Statistic
  include DataMapper::Resource
  belongs_to :pid
  
  property :id, Serial, :key => true
  
  property :accessed, DateTime, :required => true
  property :accessor, String, :length => 200, :required => true
  property :referrer, String, :length => 200
  property :target, String, :length => 2000, :required => true
  property :agent, String, :length => 2000
  property :langauge, String, :length => 200
  
  def self.flush!
    DataMapper.auto_migrate!(:default)
  end
end
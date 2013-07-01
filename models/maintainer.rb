class Maintainer
  include DataMapper::Resource
  belongs_to :group
  belongs_to :pid
  property :id, Serial, :key => true
end
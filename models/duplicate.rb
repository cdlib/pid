
class Duplicate
  include DataMapper::Resource
  
  #is :read_only
  
  storage_names[:default] = 'url_count'
  
  property :url, String, :key => true
  
  property :pid_count, Integer, :field => 'ids'
  
end
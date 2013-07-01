class User
  include DataMapper::Resource
  
  has n, :groups, :through => Resource			
  
  property :id, Serial, :key => true
  property :handle, String, :length => 20, :format => /[a-z]{3,20}+/, :unique => true, :required => true,
      :messages => {
        :presence  => "A username is required.",
        :is_unique => "We already have that username.",
        :format    => "Usernames must be a combination of 3-20 lowercase letters."
      }
  property :name, String, :length => 100, :format => /\w+/, :required => true,
      :messages => {
        :presence  => "A name is required.",
        :format    => "Names must be under 100 characters without symbols."
      }
  property :email, String, :length => 100, :format => /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}/, :required => false,
           :messages => {
           :format => "The value you entered does not a valid email address!"
      }
  property :affiliation, String, :length => 100, :format => /\.*/, :required => false,
           :messages => {
           :format	=> "Affiliations must be less than 100 characters long!"
      }
  property :password_hint, String, :length => 50, :format => /\.*/, :required => false,
           :messages => {
           :format => "The password hint must be less than 50 characters long!"
      }
      
  def self.flush!
    DataMapper.auto_migrate!()#:default)
  end
end
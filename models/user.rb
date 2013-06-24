class User
  include DataMapper::Resource
  belongs_to :group
  
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
end
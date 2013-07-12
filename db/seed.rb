puts 'Seeding the database'

#TODO - Offload these to a seed config file, default to false so that the tables do not flush!
Pid.flush!
User.flush!
Group.flush!

#TODO - Offload these to a seed config file but use the existing as a default
groups_file = File.open(ENV['HOME']+'/pid_legacy_db/groups.csv', 'r')
users_file = File.open(ENV['HOME']+'/pid_legacy_db/users.csv', 'r')
group_users_file = File.open(ENV['HOME']+'/pid_legacy_db/group_users.csv', 'r')
versions_file = File.open(ENV['HOME']+'/pid_legacy_db/versions.csv', 'r')

# ---------------------------------------------------------------
# Convert the CSV row into an instance of a DataMapper model
# ---------------------------------------------------------------
def spawn_object(obj, csv_row)
  params = {}
  
  # Loop through the items in the CSV
  csv_row.headers.each do |prop| 
    
    # If the item is a date and its null or empty use today's date
    if ['created_at', 'modified_at', 'created', 'modified'].include?(prop) && csv_row[prop].nil?
      params[prop] = Date.new
      
    # If the item is a group id, load the group object
    elsif ['group', 'group_id'].include?(prop)
      params[prop] = Group.get(csv_row[prop]).id unless Group.get(csv_row[prop]).nil?
        
    # If the item is a user id, load the user object 
    elsif ['user', 'user_id', 'userid'].include?(prop)
      params[prop] = User.get(csv_row[prop])
      
    # if the item is in the list, make sure that its in lower case
    elsif ['username', 'email'].include?(prop)
      params[prop] = csv_row[prop].downcase
      
    # If the incoming value is 'null' (case insensitive) then just set it to nil
    elsif csv_row[prop] =~ /^[Nn][Uu][Ll]{2,}$/
      params[prop] = nil  
      
    else
      params[prop] = csv_row[prop]
    end
  end

  obj.new(params)
end



puts '.... sowing groups'
# ---------------------------------------------------------------
# Process the group records
# ---------------------------------------------------------------
CSV.foreach(groups_file, :headers => true) do |row|
  group = spawn_object(Group, row)
  
  if group.valid?
    begin
      group.save
    rescue Exception => e
      puts "........ unable to create group: #{group.id} - #{group.name}"
      puts "............ #{e.message}"
    end
  else
    puts "........ unable to load user: #{group.id} - #{group.name}"
    group.errors.collect{ |e| puts "............ #{e.join(',')}" }.join(',')
    #puts "............ #{group.inspect}"
  end
  
end

#DEBUG - view loaded group records
#Group.all.each do |group|
#  puts "#{group.id} - #{group.description}"
#end


puts '.... sowing users'
# ---------------------------------------------------------------
# Process the user records
# ---------------------------------------------------------------
CSV.foreach(users_file, :headers => true) do |row|
  user = spawn_object(User, row)
  
  if user.valid?
    begin
      user.save
    rescue Exception => e
      puts "........ unable to create user: #{user.id} - #{user.name}"
      puts "............ #{e.message}"
    end
  else
    puts "........ unable to load group: #{user.id} - #{user.name}"
    user.errors.collect{ |e| puts "............ #{e.join(',')}" }.join(',')
    #puts "............ #{user.inspect}"
  end
  
end

#DEBUG - view loaded user records
#User.all.each do |user|
#  puts "#{user.id} - #{user.name}"
#end


puts ".... sowing PIDs"
# ---------------------------------------------------------------
# Process the purl version records
# ---------------------------------------------------------------
CSV.foreach(versions_file, :headers => true) do |row|
  incoming = spawn_object(Pid, row)

  params = incoming.attributes.clone.merge({:is_seed => true})
  
  # If the csv record's url was empty or null we need to deactivate the PID
  if params[:url].nil?
    params.delete(:url)
    params[:deactivated] = true
  end
  
  # See if the PID exists
  if Pid.get(incoming.id).nil?  
    # If we're minting the PID we need to make sure it has a URL
    if params[:url]
      # Set the created date and the notes if they weren't passed in the csv record
      params[:created_at] = params[:modified_at]
      params[:notes] = 'Transferred from legacy system.' if params[:notes].nil?
      
      begin
        Pid.mint(params)
      rescue Exception => e
        puts "........ unable to create pid: #{incoming.id} - #{incoming.modified_at}"
        puts "............ #{e.message}"
      end
  
    else
      puts "........ unable to create pid: #{incoming.id} - #{incoming.modified_at}"
      puts "............ the first record for a pid cannot have a null url! make sure your records are in chronological order!"
      #puts "............ #{pid.inspect}"
    end
        
  else
    begin
      Pid.get(incoming.id).revise(params)
    rescue Exception => e
      puts "........ unable to create pid: #{incoming.id} - #{incoming.modified_at}"
      puts "............ #{e.message}"
    end
  end

end

#DEBUG - view loaded user records
#Pid.all.each do |pid|
#  puts "#{pid.id} - #{pid.url} : #{pid.modified_at} - #{pid.username}"
#  pid.pid_versions.each do |ver|
#    puts "      #{ver.url} : #{ver.created_at} - #{ver.username}"
#  end
#end

puts "Finished seeding the database"



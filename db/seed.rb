seed_config = YAML.load_file('db/seed.yml')

puts 'Seeding the database'

debug = seed_config['debug_on']

# If the config specifies that we should flush the tables
if seed_config['flush_tables']
  Pid.flush!
  Maintainer.flush!
  User.flush!
  Group.flush!
end

# Load the CSV Files
csv_dir = seed_config['path'].to_s.gsub('~', ENV['HOME'])
groups_file = File.open(csv_dir + seed_config['group_file'].to_s, 'r')
users_file = File.open(csv_dir + seed_config['user_file'].to_s, 'r')
maintainers_file = File.open(csv_dir + seed_config['maintainer_file'].to_s, 'r')
versions_file = File.open(csv_dir + seed_config['pid_file'].to_s, 'r')

# ---------------------------------------------------------------
# Convert the CSV row into an instance of a DataMapper model
# ---------------------------------------------------------------
def spawn_object(obj, csv_row)
  params = {}
  
  # Loop through the items in the CSV
  csv_row.headers.each do |prop| 
    
    # If the item is a date and its null or empty use today's date
    if ['created_at', 'modified_at', 'created', 'modified'].include?(prop) && csv_row[prop].nil?
      params[prop] = Time.now
      
    # If the item is a group id, load the group object
    elsif ['group', 'group_id'].include?(prop)
      params[prop] = (prop == 'group_id') ? Group.get(csv_row[prop]).id : Group.get(csv_row[prop]) unless Group.get(csv_row[prop]).nil?
        
    # If the item is a user id, load the user object 
    elsif ['user', 'user_id', 'userid'].include?(prop)
      params[prop] = (prop == 'user') ? User.get(csv_row[prop]) : User.get(csv_row[prop]).id unless User.get(csv_row[prop]).nil?
      
    # if the item is in the list, make sure that its in lower case
    elsif ['username', 'email', 'change_category'].include?(prop)
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


puts ''
puts '.... sowing groups'
# ---------------------------------------------------------------
# Process the group records
# ---------------------------------------------------------------
i = 0; j = 0
CSV.foreach(groups_file, :headers => true) do |row|
  group = spawn_object(Group, row)
  
  if group.valid?
    begin
      group.save
      
      i = i.next
    rescue Exception => e
      puts "........ unable to create group: #{group.id} - #{group.name}"
      puts "............ #{e.message}"
    end
  else
    puts "........ unable to load user: #{group.id} - #{group.name}"
    group.errors.collect{ |e| puts "............ #{e.join(',')}" }.join(',')
    puts "............ #{group.inspect}" if debug
  end

  j = j.next
  
end
puts ".... #{i} out of #{j} groups added to the database."
puts '........ see errors above for information about the groups that could not be added.' if i != j

#DEBUG - view loaded group records
Group.all.each { |group| puts "added - #{group.id} - #{group.description}" } if debug


puts ''
puts '.... sowing users'
# ---------------------------------------------------------------
# Process the user records
# ---------------------------------------------------------------
i = 0; j = 0
CSV.foreach(users_file, :headers => true) do |row|
  user = spawn_object(User, row)
  
  if user.valid?
    begin
      user.save
      
      i = i.next
    rescue Exception => e
      puts "........ unable to create user: #{user.id} - #{user.name}"
      puts "............ #{e.message}"
    end
  else
    puts "........ unable to load user: #{user.id} - #{user.name}"
    user.errors.collect{ |e| puts "............ #{e.join(',')}" }.join(',')
    puts "............ #{user.inspect}" if debug
  end
  
  j = j.next
end
puts ".... #{i} out of #{j} users added to the database."
puts '........ see errors above for information about the users that could not be added.' if i != j


#DEBUG - view loaded user records
User.all.each { |user| puts "........ added - #{user.id} - #{user.name}" } if debug


puts ''
puts '.... connecting maintainers to their groups'
# ---------------------------------------------------------------
# Process the maintainer records
# ---------------------------------------------------------------
i = 0; j = 0
CSV.foreach(maintainers_file, :headers => true) do |row|
  maintainer = spawn_object(Maintainer, row)
  
  if maintainer.valid?
    begin
      maintainer.save
      
      i = i.next
    rescue Exception => e
      puts "........ unable to create maintainer relation between: #{maintainer.group} - #{maintainer.user}"
      puts "............ #{e.message}"
    end
  else
    puts "........ unable to load group, user: #{row}"
    maintainer.errors.collect{ |e| puts "............ #{e.join(',')}" }.join(',')
    puts "............ #{maintainer.inspect}" if debug
  end
  
  j = j.next
end
puts ".... #{i} out of #{j} maintainers added to the database."
puts '........ see errors above for information about the maintainers that could not be added.' if i != j

Maintainer.all.each { |maintainer| puts "........ made #{maintainer.user.login} a maintainer of #{maintainer.group.id}" } if debug


puts ''
puts '.... sowing PIDs'
# ---------------------------------------------------------------
# Process the pid version records
# ---------------------------------------------------------------
i = 0; j = 0; k = 0
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
        
        i = i.next
      rescue Exception => e
        puts "........ unable to create pid: #{incoming.id} - #{incoming.modified_at}"
        puts "............ #{e.message}"
        puts "............ #{incoming.inspect}" if debug
      end
  
    else
      puts "........ unable to create pid: #{incoming.id} - #{incoming.modified_at}"
      puts '............ the first record for a pid cannot have a null url! make sure your records are in chronological order!'
      puts "............ #{incoming.inspect}" if debug
    end
        
  else
    begin
      Pid.get(incoming.id).revise(params)
      
      j = j.next
    rescue Exception => e
      puts "........ unable to create pid: #{incoming.id} - #{incoming.modified_at}"
      puts "............ #{e.message}"
      puts "............ #{incoming.inspect}" if debug
    end
  end

  k = k.next
end
puts ".... #{i} new PIDs added and #{j} historical PID records (out of #{k} total records) added to the database."
puts '........ see errors above for information about the users that could not be added.' if (i + j) != k

#DEBUG - view loaded change categories
ChangeCategory.all.each { |cat| puts "added - change category: #{cat.id}" } if debug

#DEBUG - view loaded user records
if debug
  Pid.all.each do |pid|
    puts "added - #{pid.id} - #{pid.url} : #{pid.modified_at} - #{pid.username} - #{pid.change_category.inspect}"
    pid.pid_versions.each do |ver|
      puts "      history - #{ver.url} : #{ver.created_at} - #{ver.username} - #{ver.change_category.inspect}"
    end
  end
end

puts 'Finished seeding the database'
puts ''



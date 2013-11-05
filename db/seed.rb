seed_config = YAML.load_file('db/seed.yml')
config = YAML.load_file('conf/app.yml')

$stdout.puts "Seeding the database at #{Time.now}"

debug = seed_config['debug_on']

# If the config specifies that we should flush the tables
if seed_config['flush_tables']
  InvalidUrlReport.flush!
  DuplicateUrlReport.flush!
  Interested.flush!
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

#TODO Fix issue with null URLs getting through to pid.revise

def spawn_object(obj, csv_row, default_user)
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
      # If this is not a user then assume its a group and grab the first mainatiner's id
      if User.first(:login => csv_row[prop]).nil? && User.first(:id => csv_row[prop]).nil?
        # If its not a group use the default user
        if !Group.first(:id => csv_row[prop]).nil?
          params[prop] = (prop == 'user') ? Maintainer.first(:group => Group.first(:id => csv_row[prop])).user : Maintainer.first(:group => Group.first(:id => csv_row[prop])).user.id
        else
          params[prop] = User.first(:login => default_user)
        end
      else
          params[prop] = (prop == 'user') ? User.first(:login => csv_row[prop]) : User.first(:login => csv_row[prop]).id unless User.first(:login => csv_row[prop]).nil?
      end
    # if the item is in the list, make sure that its in lower case
    elsif ['username', 'email', 'change_category', 'notes'].include?(prop)
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


$stdout.puts ''
$stdout.puts '.... sowing groups'
# ---------------------------------------------------------------
# Process the group records
# ---------------------------------------------------------------
i = 0; j = 0
CSV.foreach(groups_file, :headers => true) do |row|
  group = spawn_object(Group, row, seed_config['default_user_login'])
  
  if group.valid?
    begin
      group.save
      
      i = i.next
    rescue Exception => e
      $stdout.puts "........ unable to create group: #{group.id} - #{group.name}"
      $stdout.puts "............ #{e.message}"
    end
  else
    $stdout.puts "........ unable to load user: #{group.id} - #{group.name}"
    group.errors.collect{ |e| $stdout.puts "............ #{e.join(',')}" }.join(',')
    $stdout.puts "............ #{group.inspect}" if debug
  end

  j = j.next
  
end
$stdout.puts ".... #{i} out of #{j} groups added to the database."
$stdout.puts '........ see errors above for information about the groups that could not be added.' if i != j

#DEBUG - view loaded group records
Group.all.each { |group| $stdout.puts "added - #{group.id} - #{group.description}" } if debug


$stdout.puts ''
$stdout.puts '.... sowing users'
# ---------------------------------------------------------------
# Process the user records
# ---------------------------------------------------------------
i = 0; j = 0
CSV.foreach(users_file, :headers => true) do |row|
  user = spawn_object(User, row, seed_config['default_user_login'])
  
  if user.password.nil?
    user.password = seed_config['default_password']
  end
    
  if user.valid?
    begin
      user.save
      
      i = i.next
    rescue Exception => e
      $stdout.puts "........ unable to create user: #{user.id} - #{user.name}"
      $stdout.puts "............ #{e.message}"
    end
  else
    $stdout.puts "........ unable to load user: #{user.id} - #{user.name}"
    user.errors.collect{ |e| $stdout.puts "............ #{e.join(',')}" }.join(',')
    $stdout.puts "............ #{user.inspect}" if debug
  end
  
  j = j.next
end
$stdout.puts ".... #{i} out of #{j} users added to the database."
$stdout.puts '........ see errors above for information about the users that could not be added.' if i != j


#DEBUG - view loaded user records
User.all.each { |user| $stdout.puts "........ added - #{user.id} - #{user.name}" } if debug


$stdout.puts ''
$stdout.puts '.... connecting maintainers to their groups'
# ---------------------------------------------------------------
# Process the maintainer records
# ---------------------------------------------------------------
i = 0; j = 0
CSV.foreach(maintainers_file, :headers => true) do |row|
  maintainer = spawn_object(Maintainer, row, seed_config['default_user_login'])
  
  if maintainer.valid?
    begin
      maintainer.save
      
      i = i.next
    rescue Exception => e
      $stdout.puts "........ unable to create maintainer relation between: #{maintainer.group} - #{maintainer.user}"
      $stdout.puts "............ #{e.message}"
    end
  else
    $stdout.puts "........ unable to load group, user: #{row}"
    maintainer.errors.collect{ |e| $stdout.puts "............ #{e.join(',')}" }.join(',')
    $stdout.puts "............ #{maintainer.inspect}" if debug
  end
  
  j = j.next
end
$stdout.puts ".... #{i} out of #{j} maintainers added to the database."
$stdout.puts '........ see errors above for information about the maintainers that could not be added.' if i != j

Maintainer.all.each { |maintainer| $stdout.puts "........ made #{maintainer.user.login} a maintainer of #{maintainer.group.id}" } if debug


$stdout.puts ''
$stdout.puts '.... sowing PIDs'
# ---------------------------------------------------------------
# Process the pid version records
# ---------------------------------------------------------------
i = 0; j = 0; k = 0

begin
  last_pid = nil
  dead_pid_url = config['dead_pid_url']
  
  CSV.foreach(versions_file, :headers => true) do |row|
    incoming = spawn_object(Pid, row, seed_config['default_user_login'])

    params = incoming.attributes.clone.merge({:is_seed => true})
  
    #if incoming.url.nil?
    if params[:url].nil?
      #Lookup the original url so that it doesn't get wiped out.
      chk = Pid.first(:id => incoming.id)
    
      if chk
        params[:url] = chk.url
      end
      params[:dead_pid_url] = dead_pid_url
      params[:deactivated] = true
    end
  
    # Load the user specified in the CSV
    users = incoming.username.split(', ') if incoming.username.include?(', ')
    users = incoming.username.split(' ') if users.nil?
    user = nil
    interested = []
    
    users.each do |usr|
      # If its the first user, make them the owner, all others become interested parties
      if user.nil?
        user = User.first(:login => usr.downcase) 
      else
        person = User.first(:login => usr.downcase)
        group = (person.nil?) ? Group.first(:id => usr.downcase) : person.group
        
        # Only add the group if its not already the owner of the pid
        interested << group unless group.nil? || group == user.group
      end
    end
    
    # no user could be found so use the designated default user account
    if user.nil?
      user = User.first(:login => seed_config['default_user_login'])
    end
    
    if incoming.username.include?(' ')
      params[:username] = user.login
    end
    
    # Retrieve the user's group so we can assign the PID to the group
    if !user.group.nil?
      params[:group] = user.group
    end
    
    # See if the PID exists
    if Pid.get(incoming.id).nil?  
      # If we're minting the PID we need to make sure it has a URL
      if params[:url]
        # Set the created date and the notes if they weren't passed in the csv record
        params[:created_at] = params[:modified_at]
        params[:notes] = "" if params[:notes].nil?
      
        begin
          new_pid = Pid.mint(params)
        
          interested.each do |grp|
            Interested.new(:group => grp, :pid => new_pid).save
          end
          
          i = i.next
        rescue Exception => e
          $stdout.puts "........ unable to mint pid: #{incoming.id} - #{incoming.modified_at}"
          $stdout.puts "............ #{e.message}"
          $stdout.puts "............ #{incoming.inspect}" if debug
        end
  
      else
        $stdout.puts "........ Cannot mint, No URL specified for #{incoming.id} - #{incoming.modified_at}"
        $stdout.puts "............ #{incoming.inspect}" if debug
      end
        
    else
      begin
        Pid.get(incoming.id).revise(params)
      
        j = j.next
      rescue Exception => e
        $stdout.puts "........ unable to revise pid: #{incoming.id} - #{incoming.modified_at}"
        $stdout.puts "............ #{e.message}"
        $stdout.puts "............ #{incoming.inspect}" if debug
      end
    end

    last_pid = "#{incoming.id} - #{incoming.modified_at}"  #Used to help us indicate which record failed if CSV.foreach encounters an error
    k = k.next
  end
rescue Exception => e
  $stdout.puts ".... Fatal error on CSV line after item #{last_pid}"
  $stdout.puts "........ #{e.message}"
end
$stdout.puts ".... #{i} new PIDs added and #{j} historical PID records (out of #{k} total records) added to the database."
$stdout.puts "........ see #{k - (i + j)} errors above for information about the users that could not be added." if (i + j) != k

#DEBUG - view loaded change categories
ChangeCategory.all.each { |cat| $stdout.puts "added - change category: #{cat.id}" } if debug

#DEBUG - view loaded user records
if debug
  Pid.all.each do |pid|
    $stdout.puts "added - #{pid.id} - #{pid.url} : #{pid.modified_at} - #{pid.username} - #{pid.change_category.inspect}"
    pid.pid_versions.each do |ver|
      $stdout.puts "      history - #{ver.url} : #{ver.created_at} - #{ver.username} - #{ver.change_category.inspect}"
    end
  end
end

$stdout.puts "Finished seeding the database at #{Time.now}"
$stdout.puts ''



puts 'Seeding the database'

#TODO - Offload these to a seed config file, default to false so that the tables do not flush!
Pid.flush!
User.flush!
Group.flush!

users = {}
group_users = {}
#group_maintainers = {}
#pid_maintainers = {}

#TODO - Offload these to a seed config file but use the existing as a default
groups_file = File.open(ENV['HOME']+'/pid_legacy_db/groups.csv', 'r')
users_file = File.open(ENV['HOME']+'/pid_legacy_db/users.csv', 'r')
group_users_file = File.open(ENV['HOME']+'/pid_legacy_db/group_users.csv', 'r')
versions_file = File.open(ENV['HOME']+'/pid_legacy_db/versions_sample.csv', 'r')
#versions_file = File.open(ENV['HOME']+'/pid_legacy_db/versions.csv', 'r')
  
#pid_users_file = File.open(ENV['HOME']+'/pid_legacy_db/purl_users.csv', 'r')

puts '.... sowing groups'
puts "nil: #{nil}"

# ---------------------------------------------------------------
# Process the group records
# ---------------------------------------------------------------
CSV.foreach(groups_file) do |row|
  id, name, description = row.collect { |fld| (fld) ? ((fld.strip =~ /^[Nn][Uu][Ll]{2,}$/) ? nil : fld.strip) : nil }
  
puts "id: #{id}, desc: #{description}"
  
  if id && id.upcase != 'NULL'
    group = Group.new(:id => id,
                      :name => name,
                      :description => description)
    begin
      group.save
    rescue
      group.errors.each { |err| puts err }
      puts group.inspect
    end
  else
    puts "Cannot add a group without an id! - name: #{name}, description: #{description}"
  end
  
  group_users[id] = []
#  group_maintainers[id] = []
end

#DEBUG
#Group.all.each do |group|
#  puts "#{group.id} - #{group.description}"
#end


puts '.... sowing users'
# ---------------------------------------------------------------
# Process the user records
# ---------------------------------------------------------------
while line = users_file.gets
  userid, name, email, affiliation = line.split(',')
  
  user = User.new(:login => userid.downcase,
                  :name => (name == 'NULL') ? nil : name,
                  :email => (email == 'NULL') ? nil : email.downcase,
                  :affiliation => (affiliation == 'NULL') ? nil : affiliation.gsub("\n", ''))
                   
  begin
    user.save
  rescue
    user.errors.each { |err| puts err }
    puts "#{userid} - #{user.inspect}"
  end
end

=begin
User.all.each do |user|
  puts "#{user.id} - #{user.name}"
end
=end

# ---------------------------------------------------------------
# Assign all users to the default group
# ---------------------------------------------------------------
dflt_group = Group.get('ALL')
User.all.each do |user|
  dflt_group.users << user
end
dflt_group.save


puts ".... grafting group <-> user connections"
# ---------------------------------------------------------------
# Process the group user connections (excluding default group)
# ---------------------------------------------------------------
while line = group_users_file.gets
  group, user, maintainer = line.split(',')
  
  if maintainer.gsub("\n", '').to_i == 1
    #Record the maintainers for later
    group_maintainers[group] << user
  else
    group_users[group] << user if !group_users[group].include?(user)
  end
end

Group.all.each do |group|
  unless group == dflt_group
  
    begin
      group_users[group.id].each do |login|
        user = User.first(:login => login)
        
        unless user.nil?
          group.users << user
        end
      end
      
      group.save
    rescue
      group.errors.each { |err| puts err }
      puts "Unable to add users to #{group.id} << #{users}"
    end
  end
end

=begin
Group.all.each do |group|
  puts "#{group.id}"
  group.users.each{ |user| puts "    #{user.id}" }
end
=end

puts ".... sowing PIDs"
# ---------------------------------------------------------------
# Process the purl version records
# ---------------------------------------------------------------
while line = versions_file.gets

  begin
    id, url, modified, userid, category = line.split(',')
  rescue Exception => e
    puts e.message
    puts line
  end
  
  pid = Pid.first(:id => id)

  unless pid.nil?
    begin
      pid.revise({:url => (url == 'NULL') ? pid.url : url,
                  :username => userid.downcase,
                  :change_category => category.gsub("\n", ''),
                  :modified_at => modified,
                  :deactivated => (url == 'NULL') ? 1 : 0,
                  :is_seed => true})
                  
    rescue Exception => e
      puts "Unable to add history for pid #{id} - #{e.message}"
      unless pid.nil? 
        pid.errors.each{ |k,v| puts "#{k} - #{v}" }
      end
    end
      
  else
    begin
      unless url == 'NULL'
        pid = Pid.mint(:id => id,
                       :url => url, 
                       :username => userid.downcase, 
                       :change_category => category.gsub("\n", ''), 
                       :notes => 'Entered by seeding script', 
                       :created_at => modified,
                       :modified_at => modified,
                       :deactivated => 0,
                       :is_seed => true) 
      end
    rescue Exception => e
      puts "Unable to mint new pid #{id} - #{e.message}"
      unless pid.nil? 
        pid.errors.each{ |k,v| puts "#{k} - #{v}" }
      end
    end
  end
  
end

=begin
Pid.all.each do |pid|
  puts "#{pid.id} - #{pid.url} : #{pid.modified_at} - #{pid.username}"
  pid.pid_versions.each do |ver|
    puts "      #{ver.url} : #{ver.created_at} - #{ver.username}"
  end
end
=end

puts "Finished seeding the database"
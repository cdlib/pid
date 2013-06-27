# Setup the Seed group and user
Pid.flush!
User.flush!
Group.flush!

users = {}

group_users = {}
group_maintainers = {}

pid_maintainers = {}

# ---------------------------------------------------------------
# Process the group records
# ---------------------------------------------------------------
groups_file = File.open('db/legacy_db/groups.csv', 'r')
while line = groups_file.gets
	id, name, description = line.split(',')
	
	group = Group.new(:id => id,
					  			  :name => name,
					 				  :description => (description == 'NULL') ? nil : description.gsub("\n", ''))
	begin
		group.save
	rescue
		group.errors.each { |err| puts err }
		puts group.inspect
	end
	
	group_users[id] = []
	group_maintainers[id] = []
end

=begin
Group.all.each do |group|
	puts "#{group.id} - #{group.description}"
end
=end


# ---------------------------------------------------------------
# Process the user records
# ---------------------------------------------------------------
users_file = File.open('db/legacy_db/users.csv', 'r')
while line = users_file.gets
	userid, name, email, affiliation = line.split(',')
	
	user = User.new(:handle => userid.downcase,
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


# ---------------------------------------------------------------
# Process the group user connections (excluding default group)
# ---------------------------------------------------------------
group_users_file = File.open('db/legacy_db/group_users.csv', 'r')
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
			group_users[group.id].each do |handle|
				user = User.first(:handle => handle)
				
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

=begin
# ---------------------------------------------------------------
# Process the initial purl records
# ---------------------------------------------------------------
pids_file = File.open('db/legacy_db/pids_sample.csv', 'r') 
while line = pids_file.gets
	id, url, created, modified, deactivated, username, category = line.split(",")
	
	begin
		unless url.nil?
		
			unless Pid.mint(:id => id,
						 	 				:url => url, 
						 	 				:username => username, 
						 	 				:change_category => category.gsub("\n", ''), 
					 		 				:notes => 'Entered by seeding script', 
					 		 				:created_at => created,
					 		 				:modified_at => modified,
					 		 				:deactivated => deactivated,
					 		 				:is_seed => true) 
			
				puts "Unable to save PID: #{id}!"
			end
		else
			puts "Skipping PID #{id} because the target did not match its validation or it was null."
		end
		
	rescue Exception => e
		puts "error saving PID :id"
		puts e.message
	end
	
end
=end

# ---------------------------------------------------------------
# Process the purl version records
# ---------------------------------------------------------------
versions_file = File.open('db/legacy_db/versions_sample.csv', 'r')
while line = versions_file.gets
	id, url, modified, deactivated, userid, category = line.split(',')
	
	pid = Pid.first(:id => id)

	unless pid.nil?
		begin
			#pid.url = url unless url.nil?
			#pid.username = userid
			#pid.change_category =  category.gsub("\n", '')
			#pid.modified_at = modified
			#pid.deactivated = (url == 'NULL') ? 1 : 0
			
			pid.revise({:url => (url.nil?) ? pid.url : url,
									:username => userid,
									:change_category => category.gsub("\n", ''),
									:modified_at => modified,
									:deactivated => (url == 'NULL') ? 1 : 0,
									:is_seed => true})	
			
			#Pid.mint(:id => id,
			#				 :url => (url.nil?) ? pid.url : url,
			#				 :username => userid,
			#				 :change_category => category.gsub("\n", ''),
			#				 :notes => pid.notes,
			#				 :created_at => pid.created_at,
			#				 :modified_at => modified,
			#				 :deactivated => (url == 'NULL') ? 1 : 0,
			#				 :is_seed => true)

		rescue
			puts "Unable to add history for pid #{pid.id}"
			pid.errors.each{ |err| puts err }
			puts pid.inspect
		end		
			
	else
		begin
			pid = Pid.mint(:id => id,
						 	 			 :url => url, 
						 	 			 :username => userid, 
						 	 			 :change_category => category.gsub("\n", ''), 
					 		 			 :notes => 'Entered by seeding script', 
					 		 			 :created_at => modified,
					 		 			 :modified_at => modified,
					 		 			 :deactivated => (url == 'NULL') ? 1 : 0,
					 		 			 :is_seed => true) 
		rescue Exception => e
			puts "Unable to mint new pid #{pid.id}"
			pid.errors.each{ |err| puts err }
			puts e.message
		end
	end
	
end


Pid.all.each do |pid|
	puts "#{pid.id} - #{pid.url} : #{pid.modified_at} - #{pid.username}"
	pid.pid_versions.each do |ver|
		puts "      #{ver.url} : #{ver.created_at} - #{ver.username}"
	end
end


# Save the groups

=begin
# Save the users
users.each do |userid, user|
	begin
		user.save
	rescue
		user.errors.each { |err| puts err }
		puts user.inspect
	end
end
=end

=begin
# ---------------------------------------------------------------
# Run seed validation tests
# ---------------------------------------------------------------
puts "Validating PID seed"

# URL tests
truths = {58 => "http://www.unhcr.org/cgi-bin/texis/vtx/home/opendoc.htm?tbl=RSDCOI&id=3ae6a6be4&page=research",
					1294 => "http://openurl.cdlib.org/?sid=SCP:SCP&genre=article&__char_set=utf8&issn=1432-9123",
					1484 => "http://openurl.cdlib.org/?sid=SCP:SCP&genre=article&__char_set=utf8&issn=0266-2671",
					3495 => "http://openurl.cdlib.org/?sid=SCP:SCP&genre=article&__char_set=utf8&issn=0019-2805",
					183321 => "http://opac.newsbank.com/select/shaw/1365"}
					
lies = {62 => "http://www.cdlib.org",		#Didn't load because the url was null
				101 => "http://www.cdlib.org",	#Didn't load because the url was another PID
				183312 => "http://openurl.cdlib.org/?sid=SCP:SCP&genre=article&__char_set=utf8&issn=1432-9123"} #Didn't pass because different url

lies.each do |key, value|
	pid = Pid.first(:id => key)
	if pid.nil?
		 puts ".... pass - PID #{key} was not found."
	else
		unless pid.url == value
			puts ".... pass - PID #{key} exists different url"
		else
			puts ".... fail - PID #{key} did not pass test"
		end
	end
end

truths.each do |key, value|
	pid = Pid.first(:id => key)
	unless pid.nil?
		if pid.url == value
			puts ".... pass - PID #{key} has the correct url"
		else
			puts ".... fail - PID #{key} does not have the correct url"
		end
	else
		puts ".... fail - PID #{key} was not found"
	end
end

=end
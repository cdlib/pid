# Setup the Seed group and user
Pid.flush!
group = Group.new(:id => 'SEED', :name => 'seed_group')
user = User.new(:handle => 'seed_user', :name => 'Seed User')
group.users << user
group.save

#Seed the users
users = File.open('db/legacy_db/users.csv', 'r')
while line = users.gets
	id, admin, name, affiliation, email, userid, password, hint, justification, created, modified, status, indexed = line.split(",")
	
	User.new(:handle => userid,
					 :name => name,
					 :email => email,
					 :affiliation => affiliation)
end

#Seed the groups

#Seed the domains

#Process the purl records
pids = File.open('db/legacy_db/pids.csv', 'r') 
while line = pids.gets
	id, url, validate, created, modifed, deactivated, username, category = line.split(",")
	
	begin
		if url == validate && !url.nil?
			Pid.mint(:id => id,
						 	 :url => url, 
						 	 :username => username, 
						 	 :change_category => category, 
					 		 :notes => 'Entered by seeding script', 
					 		 :created_at => created,
					 		 :modified_at => modified,
					 		 :deactivated => deactivated,
					 		 :groups => [group])
		else
			puts "skipping PID #{pid} because the target did not match its validation or it was null."
		end
		
	rescue Exception => e
		puts "error saving PID :id"
		puts e.message
	end
	
end

#validate that the Purls were minted
puts "Skipped PID 62 because target was NULL? #{Pid.first(:id => "62").nil?}"
puts "Skipped PID 101 because target is a PID? #{Pid.first(:id => "101").nil?}"

pid = Pid.first(:id => "58")
puts "Found PID 58? #{pid.url == "http://www.unhcr.org/cgi-bin/texis/vtx/home/opendoc.htm?tbl=RSDCOI&id=3ae6a6be4&page=research"}"




#url = 'http://google.com'
#url_second = 'http://uclibs.org'
#Pid.mint(:url => url, :username => user.handle, :change_category => 'Seeded', :notes => 'Entered by seeding script', :groups => [group])
#pid = Pid.mint(:url => url_second, :username => user.handle, :change_category => 'Seeded', :notes => 'Entered by seeding script', :groups => [group])
#sleep 2
#pid.revise(:url => 'http://cdlib.org', :username => user.handle, :change_category => 'Seeded', :notes => 'Revised by seeding script', :groups => [group])
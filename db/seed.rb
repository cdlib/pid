Pid.flush!
group = Group.new(:id => 'SEED', :name => 'seed_group')
user = User.new(:handle => 'seed_user', :name => 'Seed User')
group.users << user
group.save
url = 'http://google.com'
url_second = 'http://uclibs.org'
Pid.mint(:url => url, :username => user.handle, :change_category => 'Seeded', :notes => 'Entered by seeding script', :groups => [group])
pid = Pid.mint(:url => url_second, :username => user.handle, :change_category => 'Seeded', :notes => 'Entered by seeding script', :groups => [group])
sleep 2
pid.revise(:url => 'http://cdlib.org', :username => user.handle, :change_category => 'Seeded', :notes => 'Revised by seeding script', :groups => [group])
require_relative '../test_helper'

class TestPidController < Minitest::Test
  include Rack::Test::Methods

  def app
    PidApp
  end

  def setup
    Pid.flush!
    User.flush!
    Group.flush!
    Maintainer.flush!
    
    @pwd = 'secret'
    
    @group = Group.new(id: 'UCSP', name: 'test_group')
    @group2 = Group.new(id: 'UCLA', name: 'test_group2')
    @adm_grp = Group.new(id: 'ADM', name: 'test_admin_group')
    @adm = User.new(login: 'testadmin', name: 'Test Administrator', password: @pwd, email: 'purl-test-admin@cdlib.org', super: true, group: @adm_grp)
    @user = User.new(login: 'testuser', name: 'Test User', password: @pwd, email: 'purl-test-user@cdlib.org')
    @user2 = User.new(login: 'testseconduser', name: 'Test User 2', password: @pwd, email: 'purl-test-user2@cdlib.org')
    @mgr = User.new(login: 'testmgr', name: 'Test Manager', password: @pwd, email: 'purl-test-mgr@cdlib.org')
    
    @group.users << @user
    @group.users << @mgr
    @group.save
    
    @group2.users << @user2
    @group2.save
    
    @adm_grp.users << @adm
    @adm_grp.save
    
    Maintainer.create(group: @group, user: @mgr)
    Maintainer.create(group: @group2, user: @mgr)
    
    Pid.mint(url: 'http://cdlib.org', username: @user2.login, change_category: 'Test', group: @group2)
    Pid.mint(url: 'http://www.google.com', username: @user.login, change_category: 'Test', group: @group)
    Pid.mint(url: 'http://www.yahoo.com', username: @user.login, change_category: 'Test', group: @group)
    Pid.mint(url: 'http://www.huffingtonpost.com', username: @mgr.login, change_category: 'Test', group: @group)
    Pid.mint(url: 'http://www.dailybeast.com', username: @adm.login, change_category: 'Test', group: @adm_grp)
    Pid.mint(url: 'http://www.gizmodo.com', username: @adm.login, change_category: 'Test', group: @adm_grp)
    
    Interested.create(group: @group2, pid: Pid.find_by(url: 'http://www.google.com'))
  end
  
# -----------------------------------------------------------------------------------------------
  def test_get_main_menu
    security_check_basic('/link', 'get', nil)
    check_login_for_each_user_type('/link', PidApp::HTML_CONFIG['header_index'])
  end
    
# -----------------------------------------------------------------------------------------------
  def test_get_search
    security_check_basic('/link/search', 'get', nil)
    check_login_for_each_user_type('/link/search', PidApp::HTML_CONFIG['header_search_criteria'])
  end

# -----------------------------------------------------------------------------------------------
  def test_get_new
    security_check_basic('/link/new', 'get', nil)
    check_login_for_each_user_type('/link/new', PidApp::HTML_CONFIG['header_pid_register'])
  end
  
# -----------------------------------------------------------------------------------------------
  def test_get_edit
    security_check_basic('/link/edit', 'get', nil)
    check_login_for_each_user_type('/link/edit', PidApp::HTML_CONFIG['header_pid_edit'])
  end
  
# -----------------------------------------------------------------------------------------------
  def test_get_pid
    pid = Pid.find_by(url: 'http://www.yahoo.com')
    security_check_basic("/link/#{pid.id}", 'get', nil)
    check_login_for_each_user_type("/link/#{pid.id}", PidApp::HTML_CONFIG['header_pid_view'])
    
    # User can see a PID that does not belong to them
    post '/user/login', {login: @user2.login, password: @pwd}
    get "/link/#{pid.id}"
    assert last_response.ok?, "User did not receive a 200 status code trying to view a PID they do not manage, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_pid_view']), "User could not get to the PID's page!"
    refute last_response.body.include?('<input type="submit"'), "The user was able to see the submit button but they don't own the PID!"
    
    pid = Pid.find_by(url: 'http://www.google.com')

    # User CAN see a PID they are an Interested party for
    get "/link/#{pid.id}"
    assert last_response.ok?, "Interested user did not receive a 200 status code trying to view a PID they are an Interested party for, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_pid_view']), "Interested user could not get to the Interested PID's page!"
    refute last_response.body.include?('<input type="submit"'), "The user was able to see the submit button but they don't own the PID!"
    
    # Make sure a non-existent PID throws a 404
    get '/link/99999999'
    assert last_response.not_found?, "Found the specified PID. status: #{last_response.status}"
    get '/user/logout'
  end
  
# -----------------------------------------------------------------------------------------------
  def test_post_batch
    post '/user/login', {login: @user.login, password: @pwd}
    
    Pid.mint(url: 'http://news.yahoo.com', username: @user.login, change_category: 'Test', group: @group)
    Pid.mint(url: 'http://sports.yahoo.com', username: @user.login, change_category: 'Test', group: @group)
    Pid.mint(url: 'http://weather.yahoo.com', username: @user.login, change_category: 'Test', group: @group)
    
    # No file specified
    post '/link/edit', {csv: nil}
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['no_file_selected']), 'Was able to submit with no file specified!'
    
    # Non CSV file
    post '/link/edit', {csv: Rack::Test::UploadedFile.new('public/js/pid.js', 'text/csv')}
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['invalid_file_type']), 'Was able to submit a non-CSV file!!'

    # Create the test CSV file
    File.open('test/pid_batch_test.csv', 'w+') do |file|
      file.write(
        ",http://www.wikipedia.com,Batch,Testing\n" +
        ",http://finance.yahoo.com,Batch,Testing\n" +
        ",www.badurl.org,Batch,Testing\n,,Batch,Testing\n" + 
        ",http://www.gizmodo.com,Batch,Testing\n" +
        "2,http://www.adho.org,Batch,Testing\n" + 
        "3,http://www.haithitrust.com,Batch,Testing\n" +
        "1,http://www.nola.com',Batch,Testing\n" + 
        "9999999,http://www.nowhere.com',Batch,Testing\n" + # non-existent
        "#{Pid.find_by(url: 'http://weather.yahoo.com').id},,Batch,Testing\n" +  # deactivate
        "#{Pid.find_by(url: 'http://news.yahoo.com').id},http:yahoo.com,Batch,Testing\n" +  # edit bad url
        "#{Pid.find_by(url: 'http://sports.yahoo.com').id},http://cdlib.org,Batch,Testing" # edit to duplicate
      )  
    end
    
    post '/link/edit', {csv: Rack::Test::UploadedFile.new('test/pid_batch_test.csv', 'text/csv')}
    
    # 2 mints
    assert last_response.body.include?(PidApp::HTML_CONFIG['batch_mint_log']), 'Did not get a successful Mint section!'
    
    # 2 edits
    assert last_response.body.include?(PidApp::HTML_CONFIG['batch_revision_log']), 'Did not get a successful Revision section!'
    
    # Check for new Interested Party on 
    assert last_response.body.include?(PidApp::HTML_CONFIG['batch_duplicate_url_log']), 'Did not get a Interested Parties section!'
    assert Interested.find_by(group: @group, pid: Pid.find_by(url: 'http://www.gizmodo.com')), 'Did not find a new Interested Party for Gizmodo!'
    
    # Verify deactivated
    assert Pid.find_by(url: 'http://weather.yahoo.com').deactivated, 'Expected to see a deactivated PID!'

    # Failures
    assert last_response.body.include?(PidApp::HTML_CONFIG['batch_failures']), 'Did not get a failures section!'

    # non-existent PID
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['batch_process_revise_missing'].gsub('{?}', '9999999')), "Did not receive a non-existent PID message! #{last_response.body}"

    # 1 Can't mint without a url
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['batch_process_mint_inactive']), 'Did not receive a mint inactive error message'
    
    # 1 unauthorized
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['pid_unauthorized'].gsub('{?}', '1')), 'Did not receive an unauthorized message'
    
    # 2 bad urls
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['pid_mint_invalid_url'].gsub('{?}', '')), "Did not receive a mint error! #{last_response.body}"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['pid_update_invalid_url'].gsub('{?}', "#{Pid.find_by(url: 'http://news.yahoo.com').id}")), 'Did not receive a revision error!'
  end
  
# -----------------------------------------------------------------------------------------------
  def test_get_search
    # sleep so that the modification date on the pid will differ from the creation date!
    sleep(5)
    
    time_check = Time.now
    
    args = {
      pid_set: '',
      userid: '',
      groupid: '',
      active: '',
      pid_low: '',
      pid_high: '',
      modified_low: '',
      modified_high: '',
      created_low: '',
      created_high: '',
      interesteds: '0'
    }
    
    # Warning, any tests to count the number of <tr> returned should account for the <th> row!

    # Make sure users can see all pids
    args[:url] = '.com'
    post '/user/login', { login: @user.login, password: @pwd }
    get '/link/search', args
    assert last_response.ok?, "Search returned no results for the User! #{last_response.status}"
    # Commenting this test out because the search no longer requires url to have at least 4 characters as minimum criteria.
    # assert last_response.body.include?(PidApp::MESSAGE_CONFIG['pid_search_not_enough_criteria']), 'Was able to run a search with not enough criteria!'

    tr_count = Nokogiri::HTML(last_response.body).css('tr').size
    assert_equal 6, tr_count, "Expected 5 results for User but found #{tr_count - 1}"
    args[:url] = ''

    # Make sure users can see all pids
    args[:url] = 'http://'
    get '/link/search', args
    assert last_response.ok?, "Search returned no results for the User! #{last_response.status}"
    
    tr_count = Nokogiri::HTML(last_response.body).css('tr').size
    assert_equal 7, tr_count, "Expected 6 results for User but found #{tr_count - 1}"
    args[:url] = ''
    get '/user/logout'
    
    # Make sure a search for specific PIDs returns only those PIDs
    args[:pid_set] = "1\r\n3"
    args[:url] = 'http://'
    post '/user/login', {login: @mgr.login, password: @pwd}
    get '/link/search', args
    assert last_response.ok?, "Search returned no results for the Maintainer! #{last_response.status}"
    
    tr_count = Nokogiri::HTML(last_response.body).css('tr').size
    assert_equal 3, tr_count, "Expected 2 results for Maintainer but found #{tr_count - 1}"
    args[:pid_set] = ''
    args[:url] = ''
    get '/user/logout'
    
    # Make sure the user 2 finds all PIDs
    args[:url] = 'http://'
    post '/user/login', { login: @user2.login, password: @pwd }
    get '/link/search', args
    assert last_response.ok?, "Search returned no results for the User 2! #{last_response.status}"

    tr_count = Nokogiri::HTML(last_response.body).css('tr').size
    assert_equal 7, tr_count, "Expected 6 result for User 2 but found #{tr_count - 1}"
    args[:url] = ''

    # Make sure the user 2 finds their interested party PID
    args[:interesteds] = '1'
    get '/link/search', args
    assert last_response.ok?, "Search returned no results for the User 2! #{last_response.status}"

    tr_count = Nokogiri::HTML(last_response.body).css('tr').size
    assert_equal 2, tr_count, "Expected 1 result for User 2 but found #{tr_count - 1}"
    args[:interesteds] = '0'
    get '/user/logout'
    
    # Make sure maintainer can see all PIDs
    args[:url] = 'http://'
    post '/user/login', {login: @mgr.login, password: @pwd}
    get '/link/search', args
    assert last_response.ok?, "Search returned no results for the Maintainer! #{last_response.status}"
  
    tr_count = Nokogiri::HTML(last_response.body).css('tr').size
    assert_equal 7, tr_count, "Expected 6 results for Maintainer but found #{tr_count - 1}"
    args[:url] = ''
    get '/user/logout'
    
    # Make sure admin can see ALL PIDs
    args[:url] = 'http://'
    post '/user/login', {login: @adm.login, password: @pwd}
    get '/link/search', args
    assert last_response.ok?, "Search returned no results for the Admin! #{last_response.status}"

    tr_count = Nokogiri::HTML(last_response.body).css('tr').size
    assert_equal 7, tr_count, "Expected 6 results for Admin but found #{tr_count - 1}"
    args[:url] = ''
    
    # Search by specific url
    args[:url] = 'http://www.yahoo.com'
    get '/link/search', args
    assert last_response.ok?, "Search returned no results for the specific url search! #{last_response.status}"

    tr_count = Nokogiri::HTML(last_response.body).css('tr').size
    assert_equal 2, tr_count, "Expected 1 results for the specific url search but found #{tr_count - 1}"
    args[:url] = ''
    
    # Search by group
    args[:url] = 'http://'
    args[:groupid] = @group.id
    get '/link/search', args
    assert last_response.ok?, "Search returned no results for the specific group search! #{last_response.status}"

    tr_count = Nokogiri::HTML(last_response.body).css('tr').size
    assert_equal 4, tr_count, "Expected 3 results for the specific group search but found #{tr_count - 1}"
    args[:groupid] = ''
    args[:url] = ''
    
    # Search by user
    args[:userid] = @user.login
    get '/link/search', args
    assert last_response.ok?, "Search returned no results for the specific user search! #{last_response.status}"
    
    tr_count = Nokogiri::HTML(last_response.body).css('tr').size
    assert_equal 3, tr_count, "Expected 2 results for the specific user search but found #{tr_count - 1}"
    args[:userid] = ''
    
    # Search for PID range
    args[:pid_low] = 2
    args[:pid_high] = 4
    get '/link/search', args
    assert last_response.ok?, "Search returned no results for the specific pid range search! #{last_response.status}"

    tr_count = Nokogiri::HTML(last_response.body).css('tr').size
    assert_equal 4, tr_count, "Expected 3 results for the specific pid range search but found #{tr_count - 1}"
    args[:pid_low] = ''
    args[:pid_high] = ''
    
    # Search returns no results
    pid1 = Pid.find_by(url: 'http://www.yahoo.com')
    pid1.revise({ url: "#{pid1.url}/testing", group: @group })
    
    args[:modified_low] = time_check
    args[:modified_high] = Time.now
    get '/link/search', args
    assert last_response.ok?, "Search returned no results for the specific modified date range search! #{last_response.status}"

    tr_count = Nokogiri::HTML(last_response.body).css('tr').size
    assert_equal 2, tr_count, "Expected 1 results for the specific modified date range search but found #{tr_count - 1}" + last_response.body
    args[:modified_low] = ''
    args[:modified_high] = ''
    
    args[:url] = 'www.abcdefghijklmnop.org'
    get '/link/search', args
    assert last_response.ok?, "User did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['pid_search_not_found']), 'User did not get a no results messaget!'
    args[:url] = ''
    get '/user/logout'
  end
  
# -----------------------------------------------------------------------------------------------
  def test_post_pid
    # Test one new PID
    post '/user/login', { login: @user2.login, password: @pwd}
    post '/link', { new_urls: 'https://www.ucop.edu' }
    assert last_response.ok?, "User did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_pid_register_success']), 'User did not get a positive result!'
    
    # Dead URL
    post '/link', { new_urls: 'http://www.yahoo.com/test/search/12345' }
    assert last_response.ok?, "User did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_pid_register_dead_url']), 'User did not get a dead URL result!'
    
    # Bad URL format
    post '/link', { new_urls: 'www.blahblah.com' }
    assert_equal 500, last_response.status, "User did not receive a 500 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['create_pids_some_errors']), 'User did not get a failed result!'
    
    # Already existing URL just creates an Interested party
    post '/link', { new_urls: 'http://www.yahoo.com' }
    assert last_response.ok?, "User did not receive a 200 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_pid_register_duplicate_url']), 'User did not get a failed result!'
    
    # Combination of good PIDs, bad URLs, and duplicates
    post '/link', { new_urls: "http://www.blahblah.com\nwww.yahoo.com\nhttp://www.yahoo.com\nhttp://www.newone.org" }
    assert_equal 206, last_response.status, "User did not receive a 206 status code, got a #{last_response.status}"

    assert last_response.body.include?(PidApp::HTML_CONFIG['header_pid_register_success']), 'User did not get a positive result!'
    assert last_response.body.include?(PidApp::HTML_CONFIG['create_pids_some_errors']), 'User did not get a failed result!'
    assert last_response.body.include?(PidApp::HTML_CONFIG['create_pids_some_errors']), 'User did not get a failed result!'
    get '/user/logout'
    
    assert Pid.find_by(url: 'http://www.blahblah.com'), 'The PID was not minted!'
    assert_equal 1, Pid.where(url: 'http://www.yahoo.com').count, 'The system saved a duplicate URL!'
  end
  
# -----------------------------------------------------------------------------------------------
  def test_put_pid
    pid = Pid.find_by(url: 'http://www.google.com')
    
    post '/user/login', { login: @user.login, password: @pwd }
    put "/link/#{pid.id}", { url: 'http://www.pandora.com/', active: 'on'}
    assert last_response.ok?, "User did not get a 200 after updating a PID, got a #{last_response.status}!"
    passed = true if last_response.body.include?(PidApp::MESSAGE_CONFIG['pid_update_success']) or last_response.body.include?('is returning an HTTP')
    passed = true if last_response.body.include?('Connection refused') # Hack for Travis CI caused by email messages not working
    assert passed, "Did not receive the success message! #{last_response.body}"

    # Bad URL format
    put "/link/#{pid.id}", { url: 'mail.yahoo.com/', active: 'on'}
    assert last_response.ok?, "User did not receive a 500 status code, got a #{last_response.status}"
    assert last_response.body.include?(PidApp::MESSAGE_CONFIG['pid_update_invalid_url']), 'Did not receive the failure message!'
        
    pid = Pid.find_by(url: 'http://cdlib.org')
    
    # Cannot modify a PID that does not belong to user's group!
    put "/link/#{pid.id}", {url: 'http://mail.yahoo.com/', active: 'on'}
    assert_equal 403, last_response.status, 'Was expecting a 403 because the user should not be able to edit a PID they do not own!'
    assert last_response.body.include?(PidApp::HTML_CONFIG['header_unauthorized']), 'Was not sent to the unauthorized page!'
    
    # Cannot modify PID that does not exist
    put '/link/999999999', {url: 'http://www.yahoo_new.com/', active: 'on'}
    assert last_response.not_found?, "Found the specified PID. status: #{last_response.status}"
    
    get '/user/logout'
  end

# -----------------------------------------------------------------------------------------------
# -----------------------------------------------------------------------------------------------  
  def check_login_for_each_user_type(page, expected_header)
    security_check_basic(page, 'get', nil)
    
    # As a user
    post '/user/login', { login: @user.login, password: @pwd}
    get page
    assert last_response.ok?, "User did not receive a 200 status code for #{page}, got a #{last_response.status}"
    assert last_response.body.include?(expected_header), "User did not get to #{page}!"
    get '/user/logout'
    
    # As a maintainer
    post '/user/login', { login: @mgr.login, password: @pwd}
    get page
    assert last_response.ok?, "Maintainer did not receive a 200 status code for #{page}, got a #{last_response.status}"
    assert last_response.body.include?(expected_header), "Maintainer did not get to #{page}!"
    get '/user/logout'
    
    # As an admin
    post '/user/login', { login: @adm.login, password: @pwd}
    get page
    assert last_response.ok?, "Admin did not receive a 200 status code for #{page}, got a #{last_response.status}"
    assert last_response.body.include?(expected_header), "Admin did not get to #{page}!"
    get '/user/logout'
  end
  
end
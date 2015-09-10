# == PID application report generation
# This is the pid application for finding duplicate pids and presisting it in database for reporting.

require 'rubygems'
require 'bundler/setup'
require 'yaml'
require "net/http"
require 'active_record'

$stdout.puts "Starting invalid URL scan - #{Time.now}"

# Set Default Environment Variables
ENV['RACK_ENV'] ||= 'development'
ENV['APP_ROOT'] ||= File.expand_path(File.dirname(__FILE__))

# Setup Database
app_config = YAML::load(File.read(File.join(ENV['APP_ROOT'],File.exists?("conf/app.yml") ? "conf/app.yml" : 'conf/app.yml.example')))
db_config = YAML::load(File.read(File.join(ENV['APP_ROOT'],File.exists?("conf/db.yml") ? "conf/db.yml" : 'conf/db.yml.example'))) 
ActiveRecord::Base.establish_connection(db_config["activerecord_db"])

#hostname = "http://#{app_config['host']}:#{app_config['port'].to_s}/"
INVALID_URL_REPORTS_TABLE = 'invalid_url_reports'
URI_REGEX = /[fh]t{1,2}ps?:\/\/[a-zA-Z0-9\-_\.]+(:[0-9]+)?(\/[a-zA-Z0-9\/`~!@#\$%\^&\*\(\)\-_=\+{}\[\]\|\\;:'",<\.>\?])?/

#Map database schema to class object 
class InvalidUrlReport < ActiveRecord::Base; 
end

class Pid < ActiveRecord::Base; 

validates :url, presence: true
validates :url, format: { with: URI_REGEX }
end

class SkipCheck < ActiveRecord::Base;
end

#query pids table for all urls
@pid = Pid.where(deactivated: 0)

$stdout.puts "update all invalid_url_report_id references to null in pids table"
Pid.update_all(:invalid_url_report_id => nil)

$stdout.puts "delete old invalid_url_report record duplicate pids_url table"
InvalidUrlReport.delete_all

#Reset auto increment value to 0 by truncating table
ActiveRecord::Base.connection.execute("ALTER TABLE #{INVALID_URL_REPORTS_TABLE} AUTO_INCREMENT=1")


#call verify method
class UpdateUrl
   

    def verify_and_update(url, id)
	skip= false      
       #make sure the domains are not added to one at scan  
    	SkipCheck.all.each { |s| skip=true if url.downcase.include?(s.domain.downcase) }
	
	if !skip
	begin
		#Test to make sure this a valid URL
		uri = URI.parse(url)
		req = Net::HTTP.new(uri.host, uri.port)
		res = req.request_get(url)
	
		if res.code.to_i >= 300 and res.code.to_i != 302
			 invalid_url_report = InvalidUrlReport.new do |i|
			 			i.http_code = res.code.to_i
			 			i.last_checked = Time.now
						i.pid_id = id
			 			i.save  
			 		end
			 
			 pid = Pid.find_by(id: id )
			 pid.invalid_url_report_id = invalid_url_report.id;
			 pid.save
	    		
		end
	
		rescue Exception => e
	  		$stdout.puts "Failure verifying URL #{e.message} - #{url}"
			400
		end
	  else
	  	200
	  end 
      end	  
end 

u = UpdateUrl.new

#get all urls from pids table
#count = 0
@pid.all.each do |p|
#	if (count < 20)
		u.verify_and_update p.url, p.id
#	else
#		abort("abort after 20...")
#		exit 1
#	end
	#count+=1
end

$stdout.puts "Stoping Invalid URL scan - #{Time.now}"

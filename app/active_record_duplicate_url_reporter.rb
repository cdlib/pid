# == PID application report generation
# This is the pid application for finding duplicate pids and presisting it in database for reporting.

require 'rubygems'
require 'bundler/setup'
require 'yaml'
require "net/http"
require 'active_record'

$stdout.puts "Starting duplicate URL scan - #{Time.now}"

# Set Default Environment Variables
ENV['RACK_ENV'] ||= 'development'
ENV['APP_ROOT'] ||= File.expand_path(File.dirname(__FILE__))

# Setup Database
app_config = YAML::load(File.read(File.join(ENV['APP_ROOT'],File.exists?("conf/app.yml") ? "conf/app.yml" : 'conf/app.yml.example')))
db_config = YAML::load(File.read(File.join(ENV['APP_ROOT'],File.exists?("conf/db.yml") ? "conf/db.yml" : 'conf/db.yml.example'))) 
ActiveRecord::Base.establish_connection(db_config["activerecord_db"])

hostname = "http://#{app_config['host']}:#{app_config['port'].to_s}/"
DUP_URL_REPORTS_TABLE = 'duplicate_url_reports'

class DuplicateUrlReport < ActiveRecord::Base; 
end

class Pid < ActiveRecord::Base; 
end


@pid = Pid.select("GROUP_CONCAT(DISTINCT id) AS pid_ids, url").where("deactivated = 0").group('url').having("count(url) > 1")
#puts Pid.select("GROUP_CONCAT(DISTINCT id) AS pid_ids, url").where("deactivated = 0").group('url').having("count(url) > 1").explain
#puts Pid.select("GROUP_CONCAT(DISTINCT id) AS pid_ids, url").group('url').having("count(url) > 1").order("deactivated=0").explain

$stdout.puts "delete old duplicate_url_report_id references in pids table"
Pid.update_all(:duplicate_url_report_id => nil)

$stdout.puts "delete old duplicate_url_report record duplicate pids_url table"
DuplicateUrlReport.delete_all

#Reset auto increment value to 0 by truncating table
ActiveRecord::Base.connection.execute("ALTER TABLE #{DUP_URL_REPORTS_TABLE} AUTO_INCREMENT=1")

@pid.all.each do |p|
    
    pidId_arr = p.pid_ids.split(",")
    pidUrls = []
    
    # Display each value to the console.
    pidId_arr.each do |id|
       
      pidUrls << "<a href='#{hostname}link/#{id}'>#{id}</a>"   
    end
	

   duplicate_url_report_obj = DuplicateUrlReport.new do |d|
       d.other_pids = pidUrls.join(", ")
       d.last_checked = Time.now
       d.save   
   end

     pidId_arr.each do |id|
	pid = Pid.find_by(id: id )
	pid.duplicate_url_report_id = duplicate_url_report_obj.id;
     	pid.save
     end
end


$stdout.puts "Finished adding #{DuplicateUrlReport.count} URLs from the duplicate URL scan - #{Time.now}"


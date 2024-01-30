$parent_dir = File.expand_path('..', __dir__)

$LOAD_PATH.unshift(File.absolute_path(File.join($parent_dir, 'lib/shortcake')))
require 'shortcake'
require 'erb'
require 'yaml'
require 'active_record'

class PidApp
  
  $stdout.puts "Starting duplicate URL scan - #{Time.now}"
    
  app_config_file = File.exist?(File.join($parent_dir, 'config', 'app.yml')) ? File.join($parent_dir, 'config', 'app.yml') : File.join($parent_dir, 'config', 'app.yml.example')
  db_config_file = File.exist?(File.join($parent_dir, 'config', 'db.yml')) ? File.join($parent_dir, 'config', 'db.yml') : File.join($parent_dir, 'config', 'db.yml.example')
  security_config_file = File.exist?(File.join($parent_dir, 'config', 'security.yml')) ? File.join($parent_dir, 'config', 'security.yml') : File.join($parent_dir, 'config', 'security.yml.example')

  APP_CONFIG = YAML.safe_load(ERB.new(File.read(app_config_file)).result)
  DATABASE_CONFIG = YAML.safe_load(ERB.new(File.read(db_config_file)).result)
  SECURITY_CONFIG = YAML.safe_load(ERB.new(File.read(security_config_file)).result)

  URI_REGEX = /[fh]t{1,2}ps?:\/\/[a-zA-Z0-9\-_\.]+(:[0-9]+)?(\/[a-zA-Z0-9\/`~!@#\$%\^&\*\(\)\-_=\+{}\[\]\|\\;:'",<\.>\?])?/

  hostname = "http://#{APP_CONFIG['app_host']}:#{APP_CONFIG['app_port'].to_s}"

  args = {adapter: DATABASE_CONFIG['db_adapter'],
          host: DATABASE_CONFIG['db_host'],
          port: DATABASE_CONFIG['db_port'].to_i,
          database: DATABASE_CONFIG['db_name'],
          username: DATABASE_CONFIG['db_username'],
          password: DATABASE_CONFIG['db_password']}

  # Connect to the database
  $stdout.puts "Establishing connection to the #{DATABASE_CONFIG['db_name']} database on #{DATABASE_CONFIG['db_host']} - #{Time.now}"

  ActiveRecord::Base.establish_connection(args)

  # Load models
  $stdout.puts "Loading models - #{Time.now}"
  Dir.glob("#{$parent_dir}/models/*.rb").each { |r| require_relative r }

  # Delete all of the old report results
  $stdout.puts "Deleting old duplicate records - #{Time.now}"
  DuplicateUrlReport.flush!
  ActiveRecord::Base.connection.execute("ALTER TABLE duplicate_url_reports AUTO_INCREMENT = 1")

  # Add the DuplicateUrlReport records
  @pid = Pid.select("GROUP_CONCAT(DISTINCT id) AS pid_ids, url").where("deactivated = 0").group('url').having("count(url) > 1")
  @pid.each do |p|
      duplicate_url_report_obj = DuplicateUrlReport.new do |d|
        d.other_pids = p.pid_ids
        d.last_checked = Time.now
        d.save   
      end

      p.pid_ids.split(',').each do |id|
        pid = Pid.find_by(id: id)
        pid.duplicate_url_report_id = duplicate_url_report_obj.id
        pid.mutable = true
        pid.save
        pid.mutable = false
      end
  end
  
  $stdout.puts "Finished adding #{DuplicateUrlReport.count} URLs from the duplicate URL scan - #{Time.now}"
end

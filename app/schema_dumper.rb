require 'active_record'

DATABASE_CONFIG = YAML.load_file(File.exist?("conf/db.yml") ? "conf/db.yml" : 'conf/db.yml.example')

args = {
    adapter: DATABASE_CONFIG['db_adapter'],
    host: DATABASE_CONFIG['db_host'],
    port: DATABASE_CONFIG['db_port'].to_i,
    database: DATABASE_CONFIG['db_name'],
    username: DATABASE_CONFIG['db_username'],
    password: DATABASE_CONFIG['db_password']
}

ActiveRecord::Base.establish_connection(args)

File.open('db/schema.rb', 'w') do |file|
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, file)
end
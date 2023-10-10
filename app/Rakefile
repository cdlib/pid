require 'rake/testtask'

Rake::TestTask.new(:test_app) do |t|
  ENV['TESTOPTS'] ||= '-v' # default to verbose
  t.libs << "test"
  t.test_files = FileList['test/integration/test*.rb', 'test/unit/test*.rb', 'lib/*/test*.rb']
end

Rake::TestTask.new(:test_client) do |t|
  ENV['TESTOPTS'] ||= '-v' # default to verbose
  t.libs << "test"
  t.test_files = FileList['test/client/test*.rb']
end

Rake::TestTask.new(:test_redis) do |t|
  ENV['TESTOPTS'] ||= '-v' # default to verbose
  t.libs << "test"
  t.test_files = FileList['lib/shortcake/test*.rb']
end

Rake::TestTask.new(:test_unit) do |t|
  ENV['TESTOPTS'] ||= '-v' # default to verbose
  t.libs << "test"
  t.test_files = FileList['test/unit/test*.rb']
end

# Run all tests (e.g. app, client)
task :test do [:test_redis, :test_app, :test_client].each { |t| Rake::Task[t].execute }; end
task :default => :test

Dir.glob('lib/tasks/*.rake').each { |r| import r }
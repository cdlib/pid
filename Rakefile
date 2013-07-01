require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/*/test*.rb', 'lib/*/test*.rb']
  t.verbose = true
end

task :default => :test

Dir.glob('lib/tasks/*.rake').each { |r| import r }
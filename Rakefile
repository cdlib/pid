require 'rake/testtask'

Rake::TestTask.new do |t|
  ENV['TESTOPTS'] ||= '-v' # default to verbose
  t.libs << "test"
  t.test_files = FileList['test/*/test*.rb', 'lib/*/test*.rb']
  #t.verbose = true
end

task :default => :test

Dir.glob('lib/tasks/*.rake').each { |r| import r }
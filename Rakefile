require 'rake/testtask'

#Checks the remote rake file and compares for updates
#Downloads updates if applicable or downloads entire file if doesn't exist

# Unit Tests
Rake::TestTask.new task :unit_tests do |t|
  t.libs.push "lib"
  t.test_files = FileList['tests/tc_wr_azure_web*.rb']
  t.verbose = true
  t.warning = false
end

# desc 'Execute Rubocop'
# task :rubocop do
#   RuboCop::RakeTask.new
# end

# desc 'Lint with Rubocop after updating the local .rubocop.yml'
# task :lint => [:update_rubocop_config, :rubocop]

task :default => :unit_tests
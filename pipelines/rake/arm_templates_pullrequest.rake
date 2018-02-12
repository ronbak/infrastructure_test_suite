require 'rake/testtask'
require 'git'
require_relative '/tmp/infrastructure_test_suite/bin/provision'


working_dir = '/tmp/infrastructure_test_suite/'
changed_files = {}
files = File.read(ENV['changed_files'])
files.split(' ').each do |file_string|
  changed_files[file_string.split(':')[0]] = file_string.split(':')[-1]
end

task :clone_tests do
  if File.directory?("#{working_dir}.git/")
    g = Git.open(working_dir, :log => Logger.new(STDOUT))
    g.checkout('master')
    g.pull
  else
    g = Git.clone('git://github.com/chudsonwr/infrastructure_test_suite.git', 'infrastructure_test_suite', :path => '/tmp/')
  end
end

Rake::TestTask.new task :unit_tests do |t|
  t.libs.push "#{working_dir}lib"
  t.test_files = FileList["#{working_dir}tests/template/templates_tests.rb"]
  t.verbose = true
  t.warning = false
end

task :build_nonprd do
  @options = OpenStruct.new
  @options.action = 'output'
  @options.output = './nonprd_network.json'
  @options.config = 'arm_templates/networks/configs/networking_master.config.json'
  @options.verbose = false
  @options.environment = 'nonprd'
  @options.complete_deployment = true
  @options.rules = nil
  @options.skip_deploy = false
  @options.prep_templates = true
  @options.location = 'WestEurope'
  @options.scope = nil
  @options.no_upload = true

  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()

  # Build NorthEurope
  @options.output = './nonprd_eurn_network.json'
  @options.config = 'arm_templates/networks/configs/networking_eurn_master.config.json'
  @options.location = 'NorthEurope'

  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()
end

task :build_prd do
  @options = OpenStruct.new
  @options.action = 'output'
  @options.output = './prd_network.json'
  @options.config = 'arm_templates/networks/configs/networking_master.config.json'
  @options.verbose = false
  @options.environment = 'prd'
  @options.complete_deployment = true
  @options.rules = nil
  @options.skip_deploy = false
  @options.prep_templates = true
  @options.location = 'WestEurope'
  @options.scope = nil
  @options.no_upload = true

  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()

    # Build NorthEurope
  @options.output = './prd_eurn_network.json'
  @options.config = 'arm_templates/networks/configs/networking_eurn_master.config.json'
  @options.location = 'NorthEurope'

  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()
end

task :build_core do
  @options = OpenStruct.new
  @options.action = 'output'
  @options.output = './core_network.json'
  @options.config = 'arm_templates/networks/configs/networking_core.config.json'
  @options.verbose = false
  @options.environment = 'core'
  @options.complete_deployment = true
  @options.rules = nil
  @options.skip_deploy = false
  @options.prep_templates = true
  @options.location = 'WestEurope'
  @options.scope = nil
  @options.no_upload = true

  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()

  # Build EurN
  @options.output = './core_eurn_network.json'
  @options.config = 'arm_templates/networks/configs/networking_eurn_core.config.json'
  @options.location = 'NorthEurope'
  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()  
end

task :validate_templates do
  ENV['CSRE_LOG_LEVEL'] = 'DEBUG'
  puts `pwd`
  puts `ls -lah`.split("\n")
  @options = OpenStruct.new
  @options.action = 'validate'
  @options.output = './nonprd_network.json'
  @options.config = 'arm_templates/networks/configs/networking_master.config.json'
  @options.verbose = false
  @options.environment = 'nonprd'
  @options.complete_deployment = true
  @options.rules = nil
  @options.skip_deploy = false
  @options.prep_templates = true
  @options.location = 'WestEurope'
  @options.scope = nil

  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()

  @options.output = './nonprd_eurn_network.json'
  @options.config = 'arm_templates/networks/configs/networking_eurn_master.config.json'
  @options.location = 'NorthEurope'
  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()

  @options.output = './prd_network.json'
  @options.environment = 'prd'
  @options.location = 'WestEurope'
  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()
  
  @options.output = './prd_eurn_network.json'
  @options.location = 'NorthEurope'
  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()
 
  @options.config = 'arm_templates/networks/configs/networking_core.config.json'
  @options.output = './core_network.json'
  @options.environment = 'core'
  @options.location = 'WestEurope'
  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()

  @options.config = 'arm_templates/networks/configs/networking_eurn_core.config.json'
  @options.output = './core_eurn_network.json'
  @options.environment = 'core'
  @options.location = 'NorthEurope'
  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()  
end

if changed_files.keys.find { |file, commit| file.include?('/networks/') }
  task :default => [:clone_tests, :unit_tests, :build_nonprd, :build_prd, :build_core, :validate_templates] do
    puts "Building and testing all network templates"
  end
else
  task :default => [:clone_tests, :unit_tests] do
    puts "Running basic tests"
  end
end
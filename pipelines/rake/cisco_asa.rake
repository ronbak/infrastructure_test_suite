require_relative '../../bin/provision.rb'
require 'rake/testtask'

task :validate do
  puts "this is your current path: #{`pwd`}"
  puts `ls -lah`.split("\n")
  @options = OpenStruct.new
  @options.action = 'validate'
  @options.output = './arm_templates/csre/networkdevices/ciscoasav/cisco-asav-ha-mono-fast/asav-ha-template.json'
  @options.config = nil
  @options.verbose = false
  @options.environment = 'core'
  @options.complete_deployment = true
  @options.rules = nil
  @options.skip_deploy = false
  @options.prep_templates = false
  @options.location = 'WestEurope'
  @options.scope = nil
  @options.rg_name = 'cisco-asav-ha-rg-core-wr'
  ENV['CSRE_LOG_LEVEL'] = 'DEBUG'
  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()
end


task :default => [:validate,] do
  puts "Building templates and testing them"
end


require 'json'
require_relative '../lib/WRAzureResourceManagement'
require_relative '../lib/WRAzureCredentials'
require_relative '../lib/WRAzureDeployer'
require_relative '../lib/WRConfigManager'
require_relative '../lib/CSRELogger'





ENV['AZURE_CLIENT_SECRET'] = 'F9Ci6PVKnrHYoMJ2QN+iP1k/REWVuKV8N4idWhnkcGA='


environment = 'dev'
config = '../configs/jenkins2.config'


config_manager = WRConfigManager.new(config: config)

config_manager.client_name
config_manager.rg_name
config_manager.template



rg_name = 'armRubyTestRG1'



deployer = WRAzureDeployer.new(environment: environment, client_name: config_manager.client_name, rg_name: config_manager.rg_name, parameters: config_manager.parameters, template: config_manager.template)
dep_name = deployer.deploy()
deployer.deploy_status(dep_name)

x = deployer.delete()


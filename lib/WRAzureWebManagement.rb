require_relative 'CSRELogger'
require_relative 'WRAzureCredentials'
require_relative 'global_methods'
require 'azure_mgmt_web'
require 'csv'
require 'pry-byebug'

class WRAzureWebManagement

	def initialize(environment: nil, landscape: nil)
		log_level = 'INFO'
    log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
		@csrelog = CSRELogger.new(log_level, 'STDOUT')
    #environment = 'dev' if environment.nil?
    @environment = wrenvironmentdata(environment)['name']
    @landscape = landscape
		options = {environment: @environment}
		@credentials = WRAzureCredentials.new(options).authenticate()
		@web_client = Azure::ARM::Web::WebSiteManagementClient.new(@credentials)
		@web_client.subscription_id = wrmetadata()[@environment]['subscription_id']
	end

  def list_websites()
    @web_client.web_apps.list()
  end

  def list_app_service_plans()
    @web_client.app_service_plans.list()
  end

  def create_webapp_list()
    all_apps = list_websites()
    all_plans = list_app_service_plans()
    list = []
    all_plans.each do |asp|
      list << create_asp_object(asp, all_apps)
    end
    return list
  end

  def create_webapps_csv(outfile = 'webapps_list.csv')
    all_apps = list_websites()
    all_plans = list_app_service_plans()
    list = []
    all_apps.each do |webapp|
      list << create_webapps_csv_object(webapp, all_plans)
    end
    column_names = list.first.keys
    s = CSV.generate do |csv|
      csv << column_names
      list.each do |x|
        csv << x.values
      end
    end
    write_file(outfile, s)
  end

  def create_asp_object(asp, all_apps)
    asp_obj = {}
    asp_obj['name'] = asp.app_service_plan_name
    asp_obj['capacity'] = asp.sku.capacity
    asp_obj['size'] = asp.sku.size
    asp_obj['tier'] = asp.sku.tier
    asp_obj['resource_group'] = asp.resource_group
    asp_obj['maximum_number_of_workers'] = asp.maximum_number_of_workers
    asp_obj['kind'] = asp.kind
    apps_objects = []
    apps_list = all_apps.select { |app| app.server_farm_id == asp.id }
    apps_list.each do |app|
      apps_objects << create_app_object(app)
    end
    asp_obj['web_apps'] = apps_objects
    asp_obj['apps_count'] = apps_objects.count
    return asp_obj
  end

  def create_webapps_csv_object(resource, all_plans)
    obj = {}
    obj['name'] = resource.name
    obj['kind'] = resource.kind
    obj['resource_group'] = resource.id.split('resourceGroups/')[-1].split('/')[0]
    server_farm = all_plans.find { |asp| asp.id == resource.server_farm_id }
    obj['server_farm_id'] = resource.server_farm_id.split('/')[-1]
    obj['server_farm_capacity'] = server_farm.sku.capacity
    obj['server_farm_size'] = server_farm.sku.size
    obj['server_farm_tier'] = server_farm.sku.tier
    return obj
  end

  def create_app_object(webp_app)
    obj = {}
    obj['name'] = webp_app.name
    obj['size'] = webp_app.container_size
    obj['plan'] = webp_app.server_farm_id.split('/')[-1]
    obj['resource_group'] = webp_app.resource_group
    return obj
  end
end

#WRAzureWebManagement.new(environment: ARGV[0]).create_webapps_csv(ARGV[1])
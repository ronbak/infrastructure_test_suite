#!/usr/bin/env ruby
require 'simplecov'
SimpleCov.start

require 'minitest/reporters'
require 'minitest/autorun'
require 'minitest/mock'
require_relative '../../lib/WRAzureWebManagement'
require_relative '../../lib/CSRELogger'
MiniTest::Reporters.use! [MiniTest::Reporters::DefaultReporter.new,
                          MiniTest::Reporters::JUnitReporter.new]

class TestWRAzureWebManagement <  MiniTest::Test

  class AspObject
    def initialize()
      @app_service_plan_name = 'appserviecplan1'
      @maximum_number_of_workers = '10'
      @resource_group = 'my_rg_1'
      @kind = 'app'
      @sku = Sku.new()
      @id = '/appserviecplan1'
    end

    attr_reader :app_service_plan_name
    attr_reader :maximum_number_of_workers
    attr_reader :resource_group
    attr_reader :kind
    attr_reader :sku
    attr_reader :id
  end

  class Sku
    def initialize()
      @capacity = 1
      @size = 'S1'
      @tier = 'Standard'
    end

    attr_reader :capacity
    attr_reader :size
    attr_reader :tier
  end

  class AppObject
    def initialize()
      @name = 'appname1'
      @container_size = 0
      @server_farm_id = '/appserviecplan1'
      @resource_group = 'my_rg_1'
      @kind = 'app'
      @id = '/appname1'
    end

    attr_reader :name
    attr_reader :container_size
    attr_reader :server_farm_id
    attr_reader :resource_group
    attr_reader :kind
    attr_reader :id
  end

  def setup()
    # @credentials = WRAzureCredentials.new(environment: 'dev')
    # @credentials = Minitest::Mock.new
    # @credentials.expect :authenticate,  MsRest::TokenCredentials.new(MsRestAzure::ApplicationTokenProvider.new('123', '123', '123'))
    # @web_client = Azure::ARM::Web::WebSiteManagementClient.new(@credentials)

    # WRAzureCredentials.new(options).authenticate()
    @wrazwm = WRAzureWebManagement.new(environment: 'dev')

    # @credentials.stub :authenticate, MsRest::TokenCredentials.new(MsRestAzure::ApplicationTokenProvider.new('123', '123', '123')) do
    #   @wrazwm = WRAzureWebManagement.new(environment: 'dev')
    # end
  end

  def test_initialize()
    assert_instance_of(WRAzureWebManagement, @wrazwm)
  end

  def test_create_webapp_list()
    result = [{"name"=>"appserviecplan1",
      "capacity"=>1,
      "size"=>"S1",
      "tier"=>"Standard",
      "resource_group"=>"my_rg_1",
      "maximum_number_of_workers"=>"10",
      "kind"=>"app",
      "web_apps"=>[{"name"=>"appname1", "size"=>0, "plan"=>"appserviecplan1", "resource_group"=>"my_rg_1"}],
      "apps_count"=>1}]
    @wrazwm.stub :list_websites, [AppObject.new] do
      @wrazwm.stub :list_app_service_plans, [AspObject.new] do
        assert_equal(result, @wrazwm.create_webapp_list())
      end 
    end
  end

  def test_create_app_object()
    assert_equal({"name"=>"appname1", "size"=>0, "plan"=>"appserviecplan1", "resource_group"=>"my_rg_1"}, @wrazwm.create_app_object(AppObject.new))
  end

  def test_create_webapps_csv_object()
    assert_equal({"name"=>"appname1",
      "kind"=>"app",
      "resource_group"=>"",
      "server_farm_id"=>"appserviecplan1",
      "server_farm_capacity"=>1,
      "server_farm_size"=>"S1",
      "server_farm_tier"=>"Standard"},
      @wrazwm.create_webapps_csv_object(AppObject.new, [AspObject.new])
    )
  end

  def test_create_asp_object()
    assert_equal({"name"=>"appserviecplan1",
      "capacity"=>1,
      "size"=>"S1",
      "tier"=>"Standard",
      "resource_group"=>"my_rg_1",
      "maximum_number_of_workers"=>"10",
      "kind"=>"app",
      "web_apps"=>[{"name"=>"appname1", "size"=>0, "plan"=>"appserviecplan1", "resource_group"=>"my_rg_1"}],
      "apps_count"=>1},
      @wrazwm.create_asp_object(AspObject.new, [AppObject.new])
    )
  end

  def test_create_webapps_csv()
    @wrazwm.stub :list_websites, [AppObject.new] do
      @wrazwm.stub :list_app_service_plans, [AspObject.new] do
        assert_equal(141, @wrazwm.create_webapps_csv())
      end 
    end
    assert_equal("name,kind,resource_group,server_farm_id,server_farm_capacity,server_farm_size,server_farm_tier\nappname1,app,\"\",appserviecplan1,1,S1,Standard\n", File.read('webapps_list.csv'))
    File.delete('webapps_list.csv')
  end

end

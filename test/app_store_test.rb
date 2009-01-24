require 'test_helper'
require File.dirname(__FILE__) + '/../lib/app_store.rb'

class AppStoreTest < ActiveSupport::TestCase

  test "search" do
    apps = ITMS::AppStore.search("WeatherBug")
    assert apps.length >= 1
  end

  test "get app" do
    app = ITMS::AppStore.app(281940292)
  end
end

require "test_helper"

class Settings::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get settings_dashboard_index_url
    assert_response :success
  end
end

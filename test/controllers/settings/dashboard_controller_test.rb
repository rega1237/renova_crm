require "test_helper"

class Settings::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    post session_url, params: { email: @user.email, password: "password" }
  end

  test "should get index" do
    get settings_root_url # Ruta correcta para el root del namespace
    assert_response :success
  end
end

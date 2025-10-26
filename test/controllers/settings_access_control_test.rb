require "test_helper"

class SettingsAccessControlTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @tele = users(:two)
  end

  test "admin can access settings" do
    post session_url, params: { email: @admin.email, password: "password" }
    get settings_root_url
    assert_response :success
  end

  test "telemarketing cannot access settings and is notified" do
    post session_url, params: { email: @tele.email, password: "password" }
    assert_difference("UnauthorizedAccessAttempt.count", +1) do
      get settings_root_url
      assert_response :redirect
    end
    follow_redirect!
    assert_equal "Acceso no autorizado", flash[:alert]
  end
end
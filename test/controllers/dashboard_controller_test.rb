require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @tele = users(:two)
  end

  test "admin should access dashboard index" do
    post session_url, params: { email: @admin.email, password: "password" }
    get root_url
    assert_response :success
  end

  test "telemarketing should be redirected from dashboard index without alert and logged" do
    post session_url, params: { email: @tele.email, password: "password" }
    assert_difference("UnauthorizedAccessAttempt.count", +1) do
      get root_url
      assert_response :redirect
    end
    follow_redirect!
    assert_nil flash[:alert]
  end

  test "telemarketing should be blocked from metrics endpoints" do
    post session_url, params: { email: @tele.email, password: "password" }
    assert_difference("UnauthorizedAccessAttempt.count", +1) do
      get "/dashboard/leads_metrics"
      assert_response :redirect
    end
    assert_difference("UnauthorizedAccessAttempt.count", +1) do
      get "/dashboard/telemarketing_metrics"
      assert_response :redirect
    end
    assert_difference("UnauthorizedAccessAttempt.count", +1) do
      get "/dashboard/sellers_metrics"
      assert_response :redirect
    end
  end
end

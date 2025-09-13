require "test_helper"

class Settings::SellersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    post session_url, params: { email: @user.email, password: "password" }
  end

  test "should get index" do
    get settings_sellers_url # Ruta correcta
    assert_response :success
  end

  test "should get new" do
    get new_settings_seller_url # Ruta correcta
    assert_response :success
  end

  test "should create seller" do
    assert_difference("Seller.count") do
      # Usa POST y la ruta correcta
      post settings_sellers_url, params: { seller: { name: "New Seller", email: "seller@test.com", phone: "123" } }
    end
    assert_redirected_to settings_sellers_url
  end
end

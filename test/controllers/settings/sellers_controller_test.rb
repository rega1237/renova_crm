require "test_helper"

class Settings::SellersControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get settings_sellers_index_url
    assert_response :success
  end

  test "should get new" do
    get settings_sellers_new_url
    assert_response :success
  end

  test "should get create" do
    get settings_sellers_create_url
    assert_response :success
  end
end

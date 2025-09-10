require "test_helper"

class Settings::InstallersControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get settings_installers_index_url
    assert_response :success
  end

  test "should get new" do
    get settings_installers_new_url
    assert_response :success
  end

  test "should get create" do
    get settings_installers_create_url
    assert_response :success
  end
end

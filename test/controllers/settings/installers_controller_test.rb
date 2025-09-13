require "test_helper"

class Settings::InstallersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    post session_url, params: { email: @user.email, password: 'password' }
  end

  test "should get index" do
    get settings_installers_url # Ruta correcta
    assert_response :success
  end

  test "should get new" do
    get new_settings_installer_url # Ruta correcta
    assert_response :success
  end

  test "should create installer" do
    assert_difference("Installer.count") do
      # Usa POST y la ruta correcta
      post settings_installers_url, params: { installer: { name: "New Installer", email: "installer@test.com", phone: "123" } }
    end
    assert_redirected_to settings_installers_url
  end
end
require "test_helper"

class Settings::ZipcodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    post session_url, params: { email: @user.email, password: "password" }
    @city = cities(:monterrey)
    @zipcode = zipcodes(:zip_mty_64000)
  end

  test "should get index" do
    get settings_zipcodes_url
    assert_response :success
    assert_select "h1", /Códigos Postales/
  end

  test "should get new" do
    get new_settings_zipcode_url
    assert_response :success
  end

  test "should create zipcode" do
    assert_difference("Zipcode.count") do
      post settings_zipcodes_url, params: { zipcode: { code: "99999", city_id: @city.id } }
    end
    assert_redirected_to settings_zipcodes_url
  end

  test "should show zipcode" do
    get settings_zipcode_url(@zipcode)
    assert_response :success
    assert_select "h1", /Código Postal/
  end

  test "should get edit" do
    get edit_settings_zipcode_url(@zipcode)
    assert_response :success
  end

  test "should update zipcode" do
    patch settings_zipcode_url(@zipcode), params: { zipcode: { code: "64001", city_id: @city.id } }
    assert_redirected_to settings_zipcode_url(@zipcode)
    @zipcode.reload
    assert_equal "64001", @zipcode.code
  end

  test "should destroy zipcode" do
    assert_difference("Zipcode.count", -1) do
      delete settings_zipcode_url(@zipcode)
    end
    assert_redirected_to settings_zipcodes_url
  end
end

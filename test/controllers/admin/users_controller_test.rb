require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    # Inicia sesión como el usuario "one" (que es admin)
    post session_url, params: { email: @user.email, password: 'password' }
  end

  test "should get index" do
    get admin_users_url
    assert_response :success
  end

  test "should get new" do
    get new_admin_user_url
    assert_response :success
  end

  test "should create user" do
    assert_difference("User.count") do
      # Usa POST y la ruta correcta (admin_users_url)
      post admin_users_url, params: { user: { name: "New User", email: "new@example.com", password: "password", password_confirmation: "password", rol: "telemarketing" } }
    end

    assert_redirected_to admin_users_url
  end

  test "should get edit" do
    get edit_admin_user_url(@user)
    assert_response :success
  end

  test "should update user" do
    # Usa PATCH y la ruta correcta (admin_user_url)
    patch admin_user_url(@user), params: { user: { name: "Updated Name" } }
    assert_redirected_to admin_users_url
  end
end
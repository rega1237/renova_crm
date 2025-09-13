require "test_helper"

class ClientsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    # Simula un inicio de sesión publicando en la URL de la sesión
    post session_url, params: { email: @user.email, password: 'password' }
  end

  test "should get index" do
    get clients_url
    assert_response :success
  end
end

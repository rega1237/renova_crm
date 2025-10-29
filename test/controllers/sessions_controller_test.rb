require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @tele = users(:two)
  end

  test "admin redirected to dashboard after login" do
    post session_url, params: { email: @admin.email, password: "password" }
    assert_redirected_to root_url
  end

  test "telemarketing redirected to clients after login without unauthorized message" do
    post session_url, params: { email: @tele.email, password: "password" }
    assert_redirected_to clients_url
    follow_redirect!
    assert_nil flash[:alert], "Debe no mostrar mensaje de 'no autorizado' tras login"
  end

  test "non-admin respects return_to if allowed and falls back otherwise" do
    # Simular intento de visita al dashboard antes de login
    get root_url
    assert_redirected_to new_session_url
    # Hacer login como telemarketing -> debe ignorar return_to al dashboard y enviar a clientes
    post session_url, params: { email: @tele.email, password: "password" }
    assert_redirected_to clients_url
  end
end

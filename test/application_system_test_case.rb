require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Usar Selenium con Chrome para soportar JavaScript en pruebas de sistema
  driven_by :selenium, using: :chrome, screen_size: [1400, 1400]

  setup do
    login_as_admin
  end

  private
    def login_as_admin
      visit new_session_path
      fill_in "Correo Electrónico", with: users(:one).email
      fill_in "Contraseña", with: "password"
      click_on "Ingresar"
    end
end

require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :rack_test

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

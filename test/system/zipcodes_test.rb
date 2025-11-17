require "application_system_test_case"

class ZipcodesTest < ApplicationSystemTestCase
  test "navigate from settings dashboard to zipcodes index" do
    visit "/settings"
    assert_text "Configuración del Sistema"
    click_on "Gestionar Códigos Postales"
    assert_current_path "/settings/zipcodes"
    assert_text "Códigos Postales"
  end

  test "create, show, edit and delete a zipcode" do
    visit "/settings/zipcodes"
    click_on "Nuevo Código Postal"

    fill_in "Código Postal", with: "99999"
    select "Monterrey", from: "Ciudad"
    click_on "Crear Código Postal"

    assert_selector "#notifications-container", text: "Código postal creado exitosamente.", wait: 5, visible: :all

    within find("tr", text: "99999") do
      find("a[title='Editar']").click
    end
    fill_in "Código Postal", with: "99998"
    click_on "Actualizar Código Postal"
    assert_selector "#notifications-container", text: "Código postal actualizado exitosamente.", wait: 5, visible: :all

    click_on "Ver Todos los Códigos Postales"
    assert_text "99998"

    within find("tr", text: "99998") do
      accept_confirm do
        find("button[title='Eliminar']").click
      end
    end
    assert_selector "#notifications-container", text: "Código postal eliminado exitosamente.", wait: 5, visible: :all
    refute_text "99998"
  end
end

require "application_system_test_case"

class CitiesTest < ApplicationSystemTestCase
  test "navigate from settings dashboard to cities index" do
    visit "/settings"
    assert_text "Configuración del Sistema"
    click_on "Gestionar Ciudades"
    assert_current_path "/settings/cities"
    assert_text "Ciudades"
  end

  test "create, show, edit and delete a city" do
    visit "/settings/cities"
    click_on "Nueva Ciudad"

    fill_in "Nombre de la Ciudad", with: "Test City"
    fill_in "Abreviación", with: "TC"
    select "Texas", from: "Estado"
    click_on "Crear Ciudad"

    assert_text "Ciudad creada exitosamente."
    click_on "Editar Ciudad"
    fill_in "Nombre de la Ciudad", with: "Test City Updated"
    click_on "Actualizar Ciudad"
    assert_text "Ciudad actualizada exitosamente."

    click_on "Volver a la lista"
    assert_text "Test City Updated"

    # Eliminar la ciudad (envío del formulario de eliminación)
    # Selecciona el último formulario de eliminación en la tabla y lo envía
    all("form[method='post'][action*='/settings/cities']").last.find("input[type='submit']").click
    assert_text "Ciudad eliminada exitosamente."
    refute_text "Test City Updated"
  end
end
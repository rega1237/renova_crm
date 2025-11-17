require "application_system_test_case"

class CitiesTest < ApplicationSystemTestCase
  test "navigate from settings dashboard to cities index" do
    visit "/settings"
    assert_text "Configuración del Sistema"
    find("a", text: "Gestionar Ciudades").click
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

    assert_selector "#notifications-container", text: "Ciudad creada exitosamente.", wait: 5, visible: :all
    # En el índice, localizar la fila de la ciudad recién creada y hacer clic en "Editar"
    within find("tr", text: "Test City") do
      find("a[title='Editar']").click
    end
    fill_in "Nombre de la Ciudad", with: "Test City Updated"
    click_on "Actualizar Ciudad"
    assert_text "Ciudad actualizada exitosamente."

    click_on "Volver a la lista"
    assert_text "Test City Updated"

    # Eliminar la ciudad usando el botón "Eliminar" dentro de la fila correspondiente
    within find("tr", text: "Test City Updated") do
      accept_confirm do
        find("button[title='Eliminar']").click
      end
    end
    assert_text "Ciudad eliminada exitosamente."
    refute_text "Test City Updated"
  end
end

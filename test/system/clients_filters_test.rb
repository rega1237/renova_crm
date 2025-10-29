require "application_system_test_case"

class ClientsFiltersTest < ApplicationSystemTestCase
  setup do
    @texas = states(:texas)
    @florida = states(:florida)
    @monterrey = cities(:monterrey)
    @miami = cities(:miami)
    @client_with_city = clients(:one) # Monterrey, TX
    @client_without_city = clients(:two) # Florida, sin ciudad
  end

  test "filtrar por ciudad sin estado seleccionado muestra todas las ciudades" do
    visit clients_path
    assert_selector "select[name='city_id']"
    within page.find("form[action='#{clients_path}']") do
      select "Monterrey", from: "city_id"
      click_on "Filtrar"
    end
    assert_text @client_with_city.name
    assert_no_text @client_without_city.name
  end

  test "filtrar por estado limita ciudades y aplica 'Sin ciudad'" do
    visit clients_path
    within page.find("form[action='#{clients_path}']") do
      select @florida.name, from: "state_id"
      # Al seleccionar estado, el controlador stimulus carga ciudades; 'Sin ciudad' siempre está disponible
      select "Sin ciudad", from: "city_id"
      click_on "Filtrar"
    end
    assert_text @client_without_city.name
    assert_no_text @client_with_city.name
  end

  test "combinar estado y ciudad específica" do
    visit clients_path
    within page.find("form[action='#{clients_path}']") do
      select @texas.display_name_with_abbreviation, from: "state_id"
      select "Monterrey", from: "city_id"
      click_on "Filtrar"
    end
    assert_text @client_with_city.name
    assert_no_text @client_without_city.name
  end
end

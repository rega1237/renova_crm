require "application_system_test_case"

class SalesFlowFiltersTest < ApplicationSystemTestCase
  setup do
    @texas = states(:texas)
    @florida = states(:florida)
    @monterrey = cities(:monterrey)
    @miami = cities(:miami)
    @client_with_city = clients(:one) # Monterrey, TX
    @client_without_city = clients(:two) # Florida, sin ciudad
  end

  test "filtrar por ciudad en flujo de ventas" do
    visit sales_flow_path
    within page.find("form[action='#{sales_flow_path}']") do
      select "Monterrey", from: "city_id"
      click_on "Filtrar"
    end
    assert_text @client_with_city.name
    assert_no_text @client_without_city.name
  end

  test "filtrar por 'Sin ciudad' en estado Florida en flujo de ventas" do
    visit sales_flow_path
    within page.find("form[action='#{sales_flow_path}']") do
      select @florida.name, from: "state_id"
      select "Sin ciudad", from: "city_id"
      click_on "Filtrar"
    end
    assert_text @client_without_city.name
    assert_no_text @client_with_city.name
  end
end

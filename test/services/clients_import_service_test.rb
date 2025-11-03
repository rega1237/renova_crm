require "test_helper"

class ClientsImportServiceTest < ActiveSupport::TestCase
  def setup
    # Ensure fixtures are loaded
    @texas = states(:texas)
    @florida = states(:florida)
    @arizona = states(:arizona)

    @monterrey = cities(:monterrey)
    @guadalupe = cities(:guadalupe)
    @phoenix = cities(:phoenix)
    @miami = cities(:miami)

    @zip_phx_85001 = zipcodes(:zip_phx_85001)
    @zip_mia_33101 = zipcodes(:zip_mia_33101)
    @zip_mty_64000 = zipcodes(:zip_mty_64000)
    @zip_guad_67100 = zipcodes(:zip_guadalupe_67100)
  end

  def build_service
    # El servicio requiere un archivo, pero para pruebas unitarias invocamos import_row directamente.
    # Pasamos una ruta ficticia; no se usará en estas pruebas.
    ClientsImportService.new("/tmp/dummy.xlsx", current_user: nil)
  end

  def base_row(overrides = {})
    {
      "phone" => "+1555#{SecureRandom.hex(4)}",
      "name" => "Test User",
      "last_name" => "",
      "address" => "",
      "state" => "",
      "city" => "",
      "zip_code" => "",
      "status" => "lead",
      "source" => "base_de_datos"
    }.merge(overrides)
  end

  test "ZIP válido y state del Excel consistente usa state/city del ZIP" do
    s = build_service
    phone = "+1#{format('%010d', SecureRandom.random_number(10_000_000_000))}"
    row = base_row(
      "state" => @arizona.name,
      "zip_code" => @zip_phx_85001.code,
      "address" => "Phoenix, AZ #{@zip_phx_85001.code}",
      "phone" => phone
    )
    s.send(:import_row, row, false)
    client = Client.find_by(phone: phone)
    assert_equal @arizona.name, client.state.name
    assert_equal @phoenix.name, client.city.name
    assert_equal "85001", client.zip_code, "Debe guardar el ZIP de 5 dígitos en el cliente"
    assert_empty s.result.warnings.select { |w| w.include?("ZIP") && w.include?("estado") }
  end

  test "ZIP válido y conflicto con state del Excel prioriza state del Excel y city/zip 'Otro'" do
    s = build_service
    phone = "+1#{format('%010d', SecureRandom.random_number(10_000_000_000))}"
    row = base_row(
      "state" => @texas.name, # conflicto: ZIP de Arizona
      "zip_code" => @zip_phx_85001.code,
      "address" => "Phoenix, AZ #{@zip_phx_85001.code}",
      "phone" => phone
    )
    s.send(:import_row, row, false)
    client = Client.find_by(phone: phone)
    assert_equal @texas.name, client.state.name, "Debe respetar state del Excel"
    assert_not_nil client.city, "Debe asignar alguna city"
    assert_equal "Otro", client.city.name, "En conflicto, city debe ser 'Otro'"
    assert_nil client.zip_code, "En conflicto de estado/ZIP no debe guardar un ZIP que no pertenezca al estado"
    assert_includes s.result.warnings.join("\n"), "Se usa estado del Excel", "Debe registrar warning de conflicto"
    # Verificar que exista zipcode 'Otro' bajo la city
    assert Zipcode.where(city: client.city).where("LOWER(code) = ?", "otro").exists?, "Debe garantizar zipcode 'Otro'"
  end

  test "ZIP invalido, state válido usa city/zip 'Otro' bajo el state" do
    s = build_service
    phone = "+1#{format('%010d', SecureRandom.random_number(10_000_000_000))}"
    row = base_row(
      "state" => @florida.name,
      "zip_code" => "99999",
      "phone" => phone
    )
    s.send(:import_row, row, false)
    client = Client.find_by(phone: phone)
    assert_equal @florida.name, client.state.name
    assert_equal "Otro", client.city.name
    assert_includes s.result.warnings.join("\n"), "ZIP 99999 no encontrado", "Debe avisar ZIP no encontrado"
  end

  test "sin zip, con state y city existente respeta la city" do
    s = build_service
    phone = "+1#{format('%010d', SecureRandom.random_number(10_000_000_000))}"
    row = base_row(
      "state" => @texas.name,
      "city" => @guadalupe.name,
      "zip_code" => "",
      "phone" => phone
    )
    s.send(:import_row, row, false)
    client = Client.find_by(phone: phone)
    assert_equal @texas.name, client.state.name
    assert_equal @guadalupe.name, client.city.name
  end

  test "sin zip, con state y city inexistente usa city 'Otro'" do
    s = build_service
    phone = "+1#{format('%010d', SecureRandom.random_number(10_000_000_000))}"
    row = base_row(
      "state" => @texas.name,
      "city" => "CiudadInexistente",
      "zip_code" => "",
      "phone" => phone
    )
    s.send(:import_row, row, false)
    client = Client.find_by(phone: phone)
    assert_equal @texas.name, client.state.name
    assert_equal "Otro", client.city.name
    assert_includes s.result.warnings.join("\n"), "Ciudad 'CiudadInexistente' no encontrada", "Debe avisar ciudad no encontrada"
  end

  test "sin state ni zip todo 'Otro'" do
    s = build_service
    phone = "+1#{format('%010d', SecureRandom.random_number(10_000_000_000))}"
    row = base_row(
      "state" => "",
      "zip_code" => "",
      "phone" => phone
    )
    s.send(:import_row, row, false)
    client = Client.find_by(phone: phone)
    assert_equal "Otro", client.state.name
    assert_equal "Otro", client.city.name
  end

  test "ZIP se extrae desde address si no viene en columna" do
    s = build_service
    phone = "+1#{format('%010d', SecureRandom.random_number(10_000_000_000))}"
    row = base_row(
      "state" => "", # permitirá adoptar el estado del ZIP
      "zip_code" => "",
      "address" => "123 Main St, Phoenix, AZ #{@zip_phx_85001.code}",
      "phone" => phone
    )
    s.send(:import_row, row, false)
    client = Client.find_by(phone: phone)
    if client.nil?
      flunk("Client no creado. Errors: #{s.result.errors.inspect} Warnings: #{s.result.warnings.inspect}")
    end
    assert_equal @arizona.name, client.state.name
    assert_equal @phoenix.name, client.city.name
    assert_equal "85001", client.zip_code, "Debe guardar el ZIP extraido del address"
  end
end

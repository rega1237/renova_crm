require "test_helper"

class ClientsImportServiceTest < ActiveSupport::TestCase
  setup do
    # Limpiar estado 'Otro' antes de cada prueba para tener un estado consistente
    State.where("LOWER(name) = ?", "otro").destroy_all
  end

  def build_fake_xls(headers:, rows:)
    sheet = Class.new do
      define_method(:initialize) do |headers, rows|
        @headers = headers
        @rows = rows
      end

      define_method(:row) do |i|
        if i == 1
          @headers
        else
          @rows[i - 2]
        end
      end

      define_method(:last_row) do
        @rows.size + 1
      end
    end.new(headers, rows)

    Class.new do
      define_method(:sheets) do
        [ "Hoja1" ]
      end

      define_method(:sheet) do |name|
        sheet
      end
    end.new
  end

  test "asigna estado 'Otro' cuando el estado viene vacío y registra warning" do
    headers = [ "phone", "name", "state", "status", "source", "created_at" ]
    rows = [ [ "1111111", "Juan", "", "lead", "base_de_datos", Time.current ] ]
    fake_xls = build_fake_xls(headers: headers, rows: rows)

    service = ClientsImportService.new("/tmp/fake.xlsx", current_user: users(:one))
    service.singleton_class.class_eval do
      define_method(:valid_extension?) { |file| true }
      define_method(:open_spreadsheet) { |file| fake_xls }
    end

    result = service.call(update_existing: false)
    assert_equal 1, result.imported_clients_count

    otro = State.where("LOWER(name) = ?", "otro").first
    assert_not_nil otro, "Debe existir el estado 'Otro'"
    assert_equal "OTRO", otro.abbreviation, "La abreviación de 'Otro' debe ser 'OTRO'"

    client = Client.find_by(phone: "1111111")
    assert_not_nil client
    assert_equal otro, client.state

    assert result.warnings.any? { |w| w.include?("Estado vacío") && w.include?("1111111") }
  end

  test "asigna estado 'Otro' cuando el estado es desconocido y registra warning con el valor original" do
    headers = [ "phone", "name", "state", "status", "source", "created_at" ]
    rows = [ [ "2222222", "Ana", "Ficticio", "lead", "base_de_datos", Time.current ] ]
    fake_xls = build_fake_xls(headers: headers, rows: rows)

    service = ClientsImportService.new("/tmp/fake.xlsx", current_user: users(:one))
    service.singleton_class.class_eval do
      define_method(:valid_extension?) { |file| true }
      define_method(:open_spreadsheet) { |file| fake_xls }
    end

    result = service.call(update_existing: false)

    otro = State.where("LOWER(name) = ?", "otro").first
    assert_not_nil otro
    client = Client.find_by(phone: "2222222")
    assert_equal otro, client.state

    assert result.warnings.any? { |w| w.include?("Estado no encontrado: 'Ficticio'") && w.include?("2222222") }
  end

  test "no duplica el estado 'Otro' si existe en minúsculas (búsqueda case-insensitive)" do
    existing = State.create!(name: "otro", abbreviation: "OT")

    headers = [ "phone", "name", "state", "status", "source", "created_at" ]
    rows = [ [ "3333333", "Luis", "", "lead", "base_de_datos", Time.current ] ]
    fake_xls = build_fake_xls(headers: headers, rows: rows)

    service = ClientsImportService.new("/tmp/fake.xlsx", current_user: users(:one))
    service.singleton_class.class_eval do
      define_method(:valid_extension?) { |file| true }
      define_method(:open_spreadsheet) { |file| fake_xls }
    end

    service.call(update_existing: false)

    count_otro = State.where("LOWER(name) = ?", "otro").count
    assert_equal 1, count_otro, "Debe existir un único estado 'Otro'"

    client = Client.find_by(phone: "3333333")
    assert_equal existing, client.state, "Debe usar el estado existente 'otro'"
  end

  test "ensure_other_state registra error y retorna nil si falla la creación" do
    service = ClientsImportService.new("/tmp/fake.xlsx", current_user: users(:one))

    # Forzar que no exista 'otro' y que find_or_create_by falle
    State.where("LOWER(name) = ?", "otro").destroy_all

    # Stub manual de métodos de clase usando singleton_class para simular fallo
    original_where = State.method(:where)
    original_find_or_create_by = State.method(:find_or_create_by)
    begin
      State.singleton_class.send(:define_method, :where, ->(*_args) { OpenStruct.new(first: nil) })
      State.singleton_class.send(:define_method, :find_or_create_by, ->(*_args, **_kwargs, &block) { raise "DB error" })

      result = service.send(:ensure_other_state)
      assert_nil result, "Debe retornar nil cuando falla la creación"
      assert service.result.errors.any? { |e| e.include?("No se pudo asegurar estado 'Otro':") }
    ensure
      State.singleton_class.send(:define_method, :where, original_where)
      State.singleton_class.send(:define_method, :find_or_create_by, original_find_or_create_by)
    end
  end
end

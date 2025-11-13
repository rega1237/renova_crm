require "test_helper"

class ClientsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    # Simula un inicio de sesión publicando en la URL de la sesión
    post session_url, params: { email: @user.email, password: "password" }
  end

  test "should get index" do
    get clients_url
    assert_response :success
  end

  test "orden por creado cuando checkbox marcado" do
    a = clients(:one)
    b = clients(:two)

    a.update_columns(created_at: 10.days.ago)
    b.update_columns(created_at: 1.day.ago)

    get clients_url(order_by_created: "1")
    assert_response :success
    assert_select "li[id]" do |elements|
      ids = elements.map { |el| el["id"] }.compact
      idx_a = ids.index("client_#{a.id}")
      idx_b = ids.index("client_#{b.id}")
      assert idx_a && idx_b
      assert idx_b < idx_a
    end
  end

  test "comportamiento actual sin checkbox se mantiene" do
    x = clients(:one)
    y = clients(:two)

    x.update_columns(created_at: 2.days.ago)
    y.update_columns(created_at: 1.day.ago)

    get clients_url
    assert_response :success
    assert_select "li[id]" do |elements|
      ids = elements.map { |el| el["id"] }.compact
      idx_x = ids.index("client_#{x.id}")
      idx_y = ids.index("client_#{y.id}")
      assert idx_x && idx_y
      assert idx_y < idx_x
    end
  end

  test "rango de fechas con checkbox usa created_at" do
    a = clients(:one)
    b = clients(:two)

    # a: fuera de rango por created_at, dentro por updated_status_at
    a.update_columns(created_at: 30.days.ago, updated_status_at: 1.day.ago)
    # b: dentro de rango por created_at, fuera por updated_status_at
    b.update_columns(created_at: 3.days.ago, updated_status_at: 60.days.ago)

    from = 7.days.ago.to_date
    to = Date.today

    get clients_url(order_by_created: "1", date_from: from, date_to: to)
    assert_response :success
    assert_select "li[id]" do |elements|
      ids = elements.map { |el| el["id"] }.compact
      assert_includes ids, "client_#{b.id}"
      refute_includes ids, "client_#{a.id}"
    end
  end

  test "rango de fechas sin checkbox usa created_at para lead y updated_status_at para otros" do
    lead = clients(:one)
    vend = clients(:two)

    # lead dentro por created_at
    lead.update_columns(created_at: 3.days.ago, updated_status_at: 40.days.ago)
    # vendido dentro por updated_status_at, fuera por created_at
    vend.update_columns(created_at: 30.days.ago, updated_status_at: 2.days.ago)

    from = 7.days.ago.to_date
    to = Date.today

    get clients_url(date_from: from, date_to: to)
    assert_response :success
    assert_select "li[id]" do |elements|
      ids = elements.map { |el| el["id"] }.compact
      assert_includes ids, "client_#{lead.id}"
      assert_includes ids, "client_#{vend.id}"
    end
  end
end

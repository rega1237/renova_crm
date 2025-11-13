require "test_helper"

class SalesFlowControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    post session_url, params: { email: @user.email, password: "password" }
  end

  test "vendido se ordena por updated_status_at por defecto" do
    c1 = clients(:two)
    c2 = clients(:one)
    c1.update_columns(status: Client.statuses[:vendido])
    c2.update_columns(status: Client.statuses[:vendido])

    c1.update_columns(created_at: 10.days.ago, updated_status_at: 1.day.ago)
    c2.update_columns(created_at: 5.days.ago, updated_status_at: 3.days.ago)

    get sales_flow_url
    assert_response :success
    assert_select "div.kanban-column[data-status='vendido'] a.client-card" do |elements|
      ids = elements.map { |el| el["id"] }
      idx_c1 = ids.index("client_#{c1.id}")
      idx_c2 = ids.index("client_#{c2.id}")
      assert idx_c1 && idx_c2
      assert idx_c1 < idx_c2
    end
  end

  test "vendido se ordena por created_at cuando checkbox marcado" do
    c1 = Client.create!(name: "Cliente A", phone: "5551234", status: :vendido, source: :meta)
    c2 = Client.create!(name: "Cliente B", phone: "5559999", status: :vendido, source: :meta)

    c1.update_columns(created_at: 10.days.ago, updated_status_at: 1.day.ago)
    c2.update_columns(created_at: 5.days.ago, updated_status_at: 3.days.ago)

    get sales_flow_url, params: { order_by_created: "1" }
    assert_response :success
    assert_select "div.kanban-column[data-status='vendido'] a.client-card" do |elements|
      ids = elements.map { |el| el["id"] }
      idx_c1 = ids.index("client_#{c1.id}")
      idx_c2 = ids.index("client_#{c2.id}")
      assert idx_c1 && idx_c2
      assert idx_c2 < idx_c1
    end
  end

  test "rango de fechas con checkbox usa created_at en vendido" do
    c1 = clients(:two)
    c2 = clients(:one)
    c1.update_columns(status: Client.statuses[:vendido])
    c2.update_columns(status: Client.statuses[:vendido])

    # c1: fuera de rango por created_at, dentro por updated_status_at
    c1.update_columns(created_at: 30.days.ago, updated_status_at: 1.day.ago)
    # c2: dentro de rango por created_at, fuera por updated_status_at
    c2.update_columns(created_at: 3.days.ago, updated_status_at: 60.days.ago)

    from = 7.days.ago.to_date
    to = Date.today

    get sales_flow_url, params: { order_by_created: "1", date_from: from, date_to: to }
    assert_response :success
    assert_select "div.kanban-column[data-status='vendido'] a.client-card" do |elements|
      ids = elements.map { |el| el["id"] }
      assert_includes ids, "client_#{c2.id}"
      refute_includes ids, "client_#{c1.id}"
    end
  end

  test "rango de fechas sin checkbox usa updated_status_at en vendido" do
    c1 = clients(:two)
    c2 = clients(:one)
    c1.update_columns(status: Client.statuses[:vendido])
    c2.update_columns(status: Client.statuses[:vendido])

    # c1 fuera por created_at, dentro por updated_status_at
    c1.update_columns(created_at: 30.days.ago, updated_status_at: 2.days.ago)
    # c2 dentro por created_at pero fuera por updated_status_at
    c2.update_columns(created_at: 3.days.ago, updated_status_at: 60.days.ago)

    from = 7.days.ago.to_date
    to = Date.today

    get sales_flow_url, params: { date_from: from, date_to: to }
    assert_response :success
    assert_select "div.kanban-column[data-status='vendido'] a.client-card" do |elements|
      ids = elements.map { |el| el["id"] }
      assert_includes ids, "client_#{c1.id}"
      refute_includes ids, "client_#{c2.id}"
    end
  end
end

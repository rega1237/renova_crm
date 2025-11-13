require "test_helper"

class Api::CallsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(name: "Tele", email: "tele@example.com", password: "password", rol: :telemarketing)
    @state = states(:texas)
    @client = Client.create!(name: "Cliente", status: :lead, source: :otro, state: @state, phone: "+5215512345678")
    @number = Number.create!(phone_number: "+13125550123", user: @user, state: "TX", status: :active)
    # Autenticar para tener cookie de sesión válida en las requests
    post "/session", params: { email: @user.email, password: "password" }
  end

  test "requires auth" do
    # Cerrar sesión para eliminar cookie
    delete "/session"
    post "/api/calls", params: { client_id: @client.id, to_number: @client.phone }.to_json, headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :unauthorized
  end

  test "returns alternatives when no state match" do
    # user has only a number for TX, client in another state
    other_state = State.create!(name: "Illinois", abbreviation: "IL")
    @client.update!(state: other_state)

    post "/api/calls", params: { client_id: @client.id, to_number: @client.phone }.to_json, headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :ok
    body = JSON.parse(@response.body)
    assert body["need_selection"]
    assert_equal 1, body["alternatives"].size
    assert_equal @number.phone_number, body["alternatives"].first["phone_number"]
  end

  test "successful call with provided from_number" do
    fake_calls = Class.new do
      def create(from:, to:, twiml:)
        OpenStruct.new(sid: "CA123", status: "queued")
      end
    end.new
    fake_twilio = OpenStruct.new(calls: fake_calls)

    # Monkeypatch Twilio::REST::Client.new to return our fake client just for this test
    original_new = Twilio::REST::Client.method(:new)
    Twilio::REST::Client.define_singleton_method(:new) { |*args| fake_twilio }
    begin
      post "/api/calls", params: { client_id: @client.id, to_number: @client.phone, from_number: @number.phone_number }.to_json, headers: { "CONTENT_TYPE" => "application/json" }
      assert_response :success
      body = JSON.parse(@response.body)
      assert body["success"]
      assert_equal "CA123", body["sid"]
    ensure
      Twilio::REST::Client.define_singleton_method(:new) { |*args| original_new.call(*args) }
    end
  end
end

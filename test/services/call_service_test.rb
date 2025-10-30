require "test_helper"

class CallServiceTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(name: "Caller", email: "caller@example.com", password: "password", rol: :telemarketing)
    @state = states(:texas)
    @client = Client.create!(name: "Cliente", status: :lead, source: :otro, state: @state, phone: "+5215512345678")
    @number = Number.create!(phone_number: "+13125550123", user: @user, state: "TX", status: :active)
  end

  test "successful call creates note and returns sid" do
    fake_calls = Class.new do
      def create(from:, to:, twiml:)
        OpenStruct.new(sid: "CA123", status: "queued")
      end
    end.new

    fake_twilio = OpenStruct.new(calls: fake_calls)

    result = CallService.new(client: @client, to_number: @client.phone, from_number: @number.phone_number, user: @user, twilio_client: fake_twilio).call!
    assert result.success
    assert_equal "CA123", result.sid
    assert_equal "queued", result.status
    assert_equal 1, Note.where(client: @client, created_by: @user).count
  end

  test "invalid numbers return error" do
    result = CallService.new(client: @client, to_number: "123", from_number: "abc", user: @user).call!
    refute result.success
    assert_match /Números inválidos/, result.error
  end
end
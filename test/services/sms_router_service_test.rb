require "test_helper"

class SmsRouterServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    # Ensure no existing numbers interfere
    Number.delete_all
    
    @number = Number.create!(
      phone_number: "+15551234567",
      user: @user,
      state: "CA",
      status: :active
    )
  end

  test "route_inbound_sms finds user by number" do
    assert_difference "TextMessage.count", 1 do
      SmsRouterService.route_inbound_sms(
        "+15559876543", # From (client/contact)
        @number.phone_number, # To (User's number)
        "Hello World",
        "SM12345"
      )
    end

    sms = TextMessage.last
    assert_equal @user, sms.user
    assert_equal "inbound", sms.direction
    assert_equal "received", sms.status
    assert_equal @number.phone_number, sms.to_phone
  end

  test "create_outbound_sms uses user's active number" do
    assert_difference "TextMessage.count", 1 do
      SmsRouterService.create_outbound_sms(
        user: @user,
        to_phone: "+15559876543",
        message_body: "Hello Outbound"
      )
    end

    sms = TextMessage.last
    assert_equal @user, sms.user
    assert_equal "outbound", sms.direction
    assert_equal @number.phone_number, sms.from_phone
  end
end

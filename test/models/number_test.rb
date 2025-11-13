require "test_helper"

class NumberTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(name: "Test User", email: "test@example.com", password: "password", rol: :telemarketing)
  end

  test "valid number" do
    number = Number.new(phone_number: "+525512345678", user: @user, state: "MX", status: :active)
    assert number.valid?
  end

  test "invalid without phone_number" do
    number = Number.new(user: @user, state: "MX")
    refute number.valid?
    assert_includes number.errors[:phone_number], "can't be blank"
  end

  test "invalid phone_number format" do
    number = Number.new(phone_number: "555-123", user: @user, state: "MX")
    refute number.valid?
    assert_includes number.errors[:phone_number], "debe estar en formato E.164 (ej. +525512345678)"
  end

  test "requires state and user" do
    number = Number.new(phone_number: "+525512345678")
    refute number.valid?
    assert_includes number.errors[:state], "can't be blank"
    assert_includes number.errors[:user_id], "can't be blank"
  end
end

require "test_helper"

class StateTest < ActiveSupport::TestCase
  test "dependent destroy removes associated cities" do
    state = states(:arizona)
    assert_equal 1, state.cities.count, "arizona should have one city from fixtures"
    assert_difference("City.count", -1) do
      state.destroy
    end
  end
end
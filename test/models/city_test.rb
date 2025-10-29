require "test_helper"

class CityTest < ActiveSupport::TestCase
  test "valid fixture cities" do
    assert cities(:monterrey).valid?
    assert cities(:guadalupe).valid?
    assert cities(:phoenix).valid?
  end

  test "requires name" do
    city = City.new(state: states(:texas))
    assert_not city.valid?
    assert_includes city.errors.attribute_names, :name
  end

  test "requires state" do
    city = City.new(name: "Sin Estado")
    assert_not city.valid?
    assert_includes city.errors.attribute_names, :state
  end

  test "name uniqueness scoped to state" do
    existing = cities(:monterrey)
    dup_same_state = City.new(name: existing.name, state: existing.state)
    assert_not dup_same_state.valid?, "should not allow same name within same state"

    dup_other_state = City.new(name: existing.name, state: states(:florida))
    assert dup_other_state.valid?, "should allow same name in a different state"
  end

  test "abbreviation maximum length" do
    city = City.new(name: "Larga", state: states(:texas), abbreviation: "X" * 11)
    assert_not city.valid?
    assert_includes city.errors.attribute_names, :abbreviation
  end
end

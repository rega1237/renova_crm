require "test_helper"

class ZipcodeTest < ActiveSupport::TestCase
  test "valid fixture zipcodes" do
    assert zipcodes(:zip_mty_64000).valid?
    assert zipcodes(:zip_guadalupe_67100).valid?
    assert zipcodes(:zip_phx_85001).valid?
    assert zipcodes(:zip_mia_33101).valid?
  end

  test "requires code" do
    z = Zipcode.new(city: cities(:monterrey))
    assert_not z.valid?
    assert_includes z.errors.attribute_names, :code
  end

  test "requires city" do
    z = Zipcode.new(code: "99999")
    assert_not z.valid?
    assert_includes z.errors.attribute_names, :city
  end

  test "code format and length validations" do
    too_short = Zipcode.new(code: "1", city: cities(:monterrey))
    assert_not too_short.valid?
    assert_includes too_short.errors.attribute_names, :code

    too_long = Zipcode.new(code: "1" * 11, city: cities(:monterrey))
    assert_not too_long.valid?
    assert_includes too_long.errors.attribute_names, :code

    invalid_chars = Zipcode.new(code: "@@@", city: cities(:monterrey))
    assert_not invalid_chars.valid?
    assert_includes invalid_chars.errors.attribute_names, :code

    valid_mix = Zipcode.new(code: "12345-AB", city: cities(:monterrey))
    assert valid_mix.valid?
  end

  test "code uniqueness scoped to city" do
    existing = zipcodes(:zip_mty_64000)
    dup_same_city = Zipcode.new(code: existing.code, city: existing.city)
    assert_not dup_same_city.valid?, "should not allow same code within same city"

    dup_other_city = Zipcode.new(code: existing.code, city: cities(:guadalupe))
    assert dup_other_city.valid?, "should allow same code in a different city"
  end

  test "ordered scope sorts by code asc" do
    ordered_codes = Zipcode.ordered.pluck(:code)
    assert_equal ordered_codes.sort, ordered_codes
  end

  test "full_description combines code, city and state" do
    z = zipcodes(:zip_mty_64000)
    desc = z.full_description
    assert_includes desc, z.code
    assert_includes desc, z.city.name
    assert_includes desc, z.city.state.abbreviation
  end
end

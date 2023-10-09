require "test_helper"

class PlacesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get places_url
    assert_response :success
  end

  test "should create place" do
    @place = Place.new(latitude: 32.6502944, longitude: -116.983784, city: "Chula Vista", state: "CA", zipcode: "91913", country: "US", temp_unit: "fahrenheit")

    post places_url, params: {place: {city: @place.city, state: @place.state, country: @place.country, latitude: @place.latitude, longitude: @place.longitude, zipcode: @place.zipcode}}
    assert_response :success
  end
end

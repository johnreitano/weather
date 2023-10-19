# frozen_string_literal: true

require "test_helper"

class PlacesControllerTest < ActionDispatch::IntegrationTest
  test "should return home page" do
    get root_url
    assert_response :success
  end

  test "should retrieve data for a specified place" do
    Place.stub_any_instance(:retrieve_weather_data, true) do
      @place = Place.new(latitude: 32.6502944, longitude: -116.983784, city: "Chula Vista", state: "CA",
        zipcode: "91913", country: "US", temp_unit: "fahrenheit")
      post root_url,
        params: {place: {city: @place.city, state: @place.state, country: @place.country, latitude: @place.latitude,
                         longitude: @place.longitude, zipcode: @place.zipcode}}
      assert_response :success
    end
  end
end

# frozen_string_literal: true

require "test_helper"

class PlacesControllerTest < ActionDispatch::IntegrationTest
  def around(&block)
    stub_successful_open_weather_response(&block)
  end

  test "should return home page" do
    get root_url
    assert_response :success
  end

  test "should retrieve data for a specified place" do
    @place = Place.new(latitude: 32.6502944, longitude: -116.983784, city: "Chula Vista",
      state: "CA", zipcode: "91914", country: "US", temp_unit: "fahrenheit")
    Place.stub :new, @place do
      post root_url, params: {
        place: {
          city: @place.city, state: @place.state, country: @place.country,
          latitude: @place.latitude, longitude: @place.longitude, zipcode: @place.zipcode
        }
      }
      assert_response :success
    end
  end
end

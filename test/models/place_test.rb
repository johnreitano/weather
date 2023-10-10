require "test_helper"

class PlaceTest < ActiveSupport::TestCase
  setup do
    @all_attributes = {latitude: 32.6502944, longitude: -116.983784, city: "Chula Vista", state: "CA", zipcode: "91913", country: "US", temp_unit: "fahrenheit"}
    @required_fields = [:latitude, :longitude, :zipcode, :country]
    @optional_fields = [:city, :state, :temp_unit]
  end

  test "passes validation if all required fields are present" do
    place = Place.new(@all_attributes)
    assert place.valid?
  end

  test "fails validation if any required field is missing" do
    @required_fields.each do |field|
      attributes = @all_attributes.slice(@required_fields).except(field)
      place = Place.new(attributes)
      refute place.valid?
    end
  end

  test "passes validation if any optional field is missing" do
    @optional_fields.each do |field|
      attributes = @all_attributes.except(field)
      place = Place.new(attributes)
      assert place.valid?
    end
  end

  test "validate_request_and_retrieve_weather_data returns false if place is invalid" do
    place = Place.new(@all_attributes.except(:latitude))
    refute place.valid?
    refute place.validate_request_and_retrieve_weather_data
  end

  test "validate_request_and_retrieve_weather_data - calls method WeatherData#retrieve (from concern OpenWeatherDataRetriever)" do
    @@retrieve_weather_data_called = false
    place = Place.new(@all_attributes)
    weather_data = place.weather_data
    def weather_data.retrieve(opts)
      @@retrieve_weather_data_called = true
      [{}, true]
    end
    assert place.valid?
    place.validate_request_and_retrieve_weather_data
    assert @@retrieve_weather_data_called
  end
end

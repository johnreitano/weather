# frozen_string_literal: true

require "test_helper"

class PlaceTest < ActiveSupport::TestCase
  setup do
    @all_attributes = {latitude: 32.6502944, longitude: -116.983784, city: "Chula Vista", state: "CA",
                       zipcode: "91913", country: "US", temp_unit: "fahrenheit"}
    @required_fields = %i[latitude longitude zipcode country]
    @optional_fields = %i[city state temp_unit]
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

  test "retrieve_weather_data returns false if place is invalid" do
    place = Place.new(@all_attributes.except(:latitude))
    refute place.valid?
    refute place.retrieve_weather_data
  end

  test "retrieve_weather_data - calls method WeatherData#retrieve (from concern OpenWeatherDataRetriever)" do
    place = Place.new(@all_attributes)
    weather_data = place.weather_data
    def weather_data.retrieve(_)
      @retrieve_weather_data_called = true
      [{}, true]
    end
    assert place.valid?
    refute place.weather_data.instance_variable_get(:@retrieve_weather_data_called)
    place.retrieve_weather_data
    assert place.weather_data.instance_variable_get(:@retrieve_weather_data_called)
  end
end

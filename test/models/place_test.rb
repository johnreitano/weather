require "test_helper"

class PlaceTest < ActiveSupport::TestCase
  setup do
    @all_attributes = {latitude: 32.6502944, longitude: -116.983784, city: "Chula Vista", state: "CA", zipcode: "91913", country: "US", temp_unit: "fahrenheit"}
    @required_fields = [:latitude, :longitude, :zipcode, :country]
    @optional_fields = [:city, :state, :temp_unit]

    @complete_weather_data = {current_temp: 87.2, days: [{day: "Sat 07", low: 70.6, high: 87.2}, {day: "Sun 08", low: 72.7, high: 88.9}, {day: "Mon 09", low: 67.6, high: 81.2}, {day: "Tue 10", low: 64.0, high: 73.7}, {day: "Wed 11", low: 65.0, high: 72.3}, {day: "Thu 12", low: 63.6, high: 73.5}, {day: "Fri 13", low: 64.2, high: 74.0}, {day: "Sat 14", low: 63.6, high: 74.6}], cached: false}
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

  test "retrieve_weather returns false if place is invalid" do
    skip
  end

  test "retrieve_weather calls OpenWeatherClient.retrieve_weather, on success storing the result in the field 'weather_data'" do
    skip
  end

  test "retrieve_weather calls OpenWeatherClient.retrieve_weather, on failure adding an error to the field 'weather_data'" do
    skip
  end

  test "current_temp returns the correct value after attempting to extract it from weather_data" do
    place = Place.new

    place.weather_data = nil
    assert_nil place.current_temp

    place.weather_data = {}
    assert_nil place.current_temp

    place.weather_data = {current_temp: nil}
    assert_nil place.current_temp

    place.weather_data = {current_temp: 30.0}
    assert_equal 30.0, place.current_temp
  end

  test "retrieved_at returns the correct value after attempting to extract it from weather_data" do
    skip
  end

  test "current_day_low returns the correct value after attempting to extract it from weather_data" do
    skip
  end

  test "current_day_high returns the correct value after attempting to extract it from weather_data" do
    skip
  end

  test "day_description returns the correct value after attempting to extract it from weather_data" do
    skip
  end

  test "day_low returns the correct value after attempting to extract it from weather_data" do
    skip
  end

  test "day_high returns the correct value after attempting to extract it from weather_data" do
    skip
  end

  test "has_weather_data? returns false if any required component of data is missing" do
    place = Place.new

    place.weather_data = nil
    refute place.has_weather_data?

    place.weather_data = {}
    refute place.has_weather_data?

    place.weather_data = @complete_weather_data.except(:current_temp)
    refute place.has_weather_data?

    place.weather_data = @complete_weather_data.except(:days)
    refute place.has_weather_data?

    place.weather_data = @complete_weather_data.dup
    place.weather_data[:days] = []
    refute place.has_weather_data?

    place.weather_data = @complete_weather_data.dup
    place.weather_data[:days].pop
    refute place.has_weather_data?
  end

  test "has_weather_data? returns true if all required components of data are present" do
    place = Place.new
    place.weather_data = @complete_weather_data
    assert place.has_weather_data?
  end
end

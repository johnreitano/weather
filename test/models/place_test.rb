require "test_helper"

class PlaceTest < ActiveSupport::TestCase
  setup do
    @all_attributes = {latitude: 32.6502944, longitude: -116.983784, city: "Chula Vista", state: "CA", zipcode: "91913", country: "US", temp_unit: "fahrenheit"}
    @required_fields = [:latitude, :longitude, :zipcode, :country]
    @optional_fields = [:city, :state, :temp_unit]

    @complete_weather_data = {current_temp: 87.2, cached_at: Time.now, days: [{day_label: "Sat 07", low: 70.6, high: 87.2}, {day_label: "Sun 08", low: 72.7, high: 88.9}, {day_label: "Mon 09", low: 67.6, high: 81.2}, {day_label: "Tue 10", low: 64.0, high: 73.7}, {day_label: "Wed 11", low: 65.0, high: 72.3}, {day_label: "Thu 12", low: 63.6, high: 73.5}, {day_label: "Fri 13", low: 64.2, high: 74.0}, {day_label: "Sat 14", low: 63.6, high: 74.6}], retrieved_from_cache: false}
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
    place = Place.new(@all_attributes.except(:latitude))
    refute place.valid?
    refute place.retrieve_weather
  end

  test "retrieve_weather - calls OpenWeatherClient.retrieve_weather" do
    mock = Minitest::Mock.new
    attrs = @all_attributes.slice(:latitude, :longitude, :city, :state, :zipcode, :country, :temp_unit)
    mock.expect :retrieve_weather, [@complete_weather_data, true], [attrs]

    place = Place.new(@all_attributes)
    place.instance_variable_set(:@open_weather_client, mock) # use mock instead of OpenWeatherClient
    place.retrieve_weather
  end

  test "retrieve_weather - when call to OpenWeatherClient.retrieve_weather succeeds, stores resulting data in the field 'weather_data'" do
    place = Place.new(@all_attributes)
    refute place.has_weather_data?
    OpenWeatherClient.stub :retrieve_weather, [@complete_weather_data, true] do
      assert place.retrieve_weather
      assert place.has_weather_data?
      assert_equal @complete_weather_data, place.weather_data
    end
  end

  test "retrieve_weather - when call to OpenWeatherClient.retrieve_weather fails, stores empty hash in 'weather_data'" do
    place = Place.new(@all_attributes)
    refute place.has_weather_data?
    OpenWeatherClient.stub :retrieve_weather, [{}, false] do
      refute place.retrieve_weather
      refute place.has_weather_data?
      assert_equal({}, place.weather_data)
    end
  end

  test "current_temp returns the correct value after attempting to extract it from weather_data" do
    place = Place.new

    assert_nil place.current_temp

    place.instance_variable_set(:@weather_data, {current_temp: nil})
    assert_nil place.current_temp

    place.instance_variable_set(:@weather_data, {current_temp: 30.0})
    assert_equal 30.0, place.current_temp
  end

  test "cached_at returns the correct value in Pacific Time after attempting to extract it from weather_data" do
    place = Place.new

    assert_nil place.cached_at

    place.instance_variable_set(:@weather_data, {cached_at: nil})
    assert_nil place.cached_at

    t = Time.new(2023, 9, 1, 12, 0, 0, "-04:00") # 12pm EDT
    place.instance_variable_set(:@weather_data, {cached_at: t})
    assert_equal "9:00am PDT", place.cached_at
  end

  test "current_day_low returns the correct value after attempting to extract it from weather_data" do
    place = Place.new

    assert_nil place.current_day_low

    place.instance_variable_set(:@weather_data, {days: []})
    assert_nil place.current_day_low

    place.instance_variable_set(:@weather_data, @complete_weather_data)
    assert_equal 70.6, place.current_day_low
  end

  test "current_day_high returns the correct value after attempting to extract it from weather_data" do
    place = Place.new

    assert_nil place.current_day_high

    place.instance_variable_set(:@weather_data, {days: []})
    assert_nil place.current_day_high

    place.instance_variable_set(:@weather_data, @complete_weather_data)
    assert_equal 87.2, place.current_day_high
  end

  test "day_* methods return correct values after attempting to extract them from weather_data" do
    place = Place.new

    assert_nil place.day_label(1)
    assert_nil place.day_low(1)
    assert_nil place.day_high(1)

    place.instance_variable_set(:@weather_data, {days: []})
    assert_nil place.day_label(1)
    assert_nil place.day_low(1)
    assert_nil place.day_high(1)

    place.instance_variable_set(:@weather_data, @complete_weather_data)
    assert_equal "Sun 08", place.day_label(1)
    assert_equal "Mon 09", place.day_label(2)
    assert_equal 72.7, place.day_low(1)
    assert_equal 67.6, place.day_low(2)
    assert_equal 88.9, place.day_high(1)
    assert_equal 81.2, place.day_high(2)
  end

  test "attribute weather_data is an empty hash after creating new object" do
    place = Place.new
    assert_equal({}, place.weather_data)
  end

  test "has_weather_data? returns false if any required component of data is missing" do
    place = Place.new
    refute place.has_weather_data?

    place.instance_variable_set(:@weather_data, @complete_weather_data.except(:current_temp))
    refute place.has_weather_data?

    place.instance_variable_set(:@weather_data, @complete_weather_data.except(:cached_at))
    refute place.has_weather_data?

    place.instance_variable_set(:@weather_data, @complete_weather_data.except(:days))
    refute place.has_weather_data?

    place.instance_variable_set(:@weather_data, @complete_weather_data.merge(days: []))
    refute place.has_weather_data?

    # remove last item from forecast data
    partial_weather_data = @complete_weather_data.dup
    partial_weather_data[:days].pop
    place.instance_variable_set(:@weather_data, partial_weather_data)
    refute place.has_weather_data?
  end

  test "has_weather_data? returns true if all required components of data are present" do
    place = Place.new
    place.instance_variable_set(:@weather_data, @complete_weather_data)
    assert place.has_weather_data?
  end
end

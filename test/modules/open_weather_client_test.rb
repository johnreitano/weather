require "test_helper"

class OpenWeatherClientTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear

    Timecop.freeze(Time.local(2023, 9, 1, 12, 0, 0))

    # stub for returning data in successful scenarios
    def OpenWeatherClient.load_raw_data(opts)
      [{"current" => {"temp" => 303.82}, "daily" => [{"dt" => "2023-10-07 19:00:00 UTC".to_datetime, "temp" => {"min" => 294.61, "max" => 303.82}}, {"dt" => "2023-10-08 19:00:00 UTC".to_datetime, "temp" => {"min" => 295.77, "max" => 304.76}}, {"dt" => "2023-10-09 19:00:00 UTC".to_datetime, "temp" => {"min" => 292.9, "max" => 300.5}}, {"dt" => "2023-10-10 19:00:00 UTC".to_datetime, "temp" => {"min" => 290.95, "max" => 296.3}}, {"dt" => "2023-10-11 19:00:00 UTC".to_datetime, "temp" => {"min" => 291.47, "max" => 295.51}}, {"dt" => "2023-10-12 19:00:00 UTC".to_datetime, "temp" => {"min" => 290.68, "max" => 296.23}}, {"dt" => "2023-10-13 19:00:00 UTC".to_datetime, "temp" => {"min" => 291.02, "max" => 296.48}}, {"dt" => "2023-10-14 19:00:00 UTC".to_datetime, "temp" => {"min" => 290.71, "max" => 296.79}}]}, true]
    end

    now = Time.now.in_time_zone("Pacific Time (US & Canada)")

    @expected_fahrenheit_data = {current_temp: 87.2, retrieved_at: now, days: [{day: "Sat 07", low: 70.6, high: 87.2}, {day: "Sun 08", low: 72.7, high: 88.9}, {day: "Mon 09", low: 67.6, high: 81.2}, {day: "Tue 10", low: 64.0, high: 73.7}, {day: "Wed 11", low: 65.0, high: 72.3}, {day: "Thu 12", low: 63.6, high: 73.5}, {day: "Fri 13", low: 64.2, high: 74.0}, {day: "Sat 14", low: 63.6, high: 74.6}], cached: false}

    @expected_celsius_data = {current_temp: 30.7, retrieved_at: now, days: [{day: "Sat 07", low: 21.5, high: 30.7}, {day: "Sun 08", low: 22.6, high: 31.6}, {day: "Mon 09", low: 19.8, high: 27.4}, {day: "Tue 10", low: 17.8, high: 23.2}, {day: "Wed 11", low: 18.3, high: 22.4}, {day: "Thu 12", low: 17.5, high: 23.1}, {day: "Fri 13", low: 17.9, high: 23.3}, {day: "Sat 14", low: 17.6, high: 23.6}], cached: false}
  end

  teardown do
    Timecop.return
  end

  test "retrieve weather (fahrenheit)" do
    data, success = OpenWeatherClient.retrieve_weather(latitude: 32.6502944, longitude: -116.983784, city: "Chula Vista", state: "CA", zipcode: "91913", country: "US", temp_unit: "fahrenheit")
    assert_equal [@expected_fahrenheit_data, true], [data, success]
  end

  test "retrieve weather (celsius)" do
    data, success = OpenWeatherClient.retrieve_weather(latitude: 32.6502944, longitude: -116.983784, city: "Chula Vista", state: "CA", zipcode: "91913", country: "US", temp_unit: "celsius")
    assert_equal [@expected_celsius_data, true], [data, success]
  end

  test "should return cached result on second request" do
    data, success = OpenWeatherClient.retrieve_weather(latitude: 32.6502944, longitude: -116.983784, city: "Chula Vista", state: "CA", zipcode: "91913", country: "US", temp_unit: "fahrenheit")
    assert_equal [@expected_fahrenheit_data, true], [data, success]

    @expected_fahrenheit_data[:cached] = true
    data, success = OpenWeatherClient.retrieve_weather(latitude: 32.6502944, longitude: -116.983784, city: "Chula Vista", state: "CA", zipcode: "91913", country: "US", temp_unit: "fahrenheit")
    assert_equal [@expected_fahrenheit_data, true], [data, success]
  end

  test "should fail gracefully when required field is missing" do
    # leaving out latitude
    data, success = OpenWeatherClient.retrieve_weather(longitude: 200, city: "Chula Vista", state: "CA", zipcode: "91913", country: "US", temp_unit: "fahrenheit")
    assert_equal [{}, false], [data, success]
  end

  test "should fail gracefully when OpenWeather cannot return data" do
    # stub for returning data in failure scenario
    def OpenWeatherClient.load_raw_data(opts)
      [{}, false]
    end

    data, success = OpenWeatherClient.retrieve_weather(latitude: 200, longitude: 200, city: "Chula Vista", state: "CA", zipcode: "91913", country: "US", temp_unit: "fahrenheit")
    assert_equal [{}, false], [data, success]
  end
end

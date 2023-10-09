require "test_helper"

class OpenWeatherClientTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear

    Time.zone = "Eastern Time (US & Canada)"
    Timecop.freeze(Time.zone.local(2023, 9, 1, 12, 0, 0))

    # stub for returning data in successful scenarios
    def OpenWeatherClient.download_raw_data(opts)
      [{"current" => {"temp" => 303.82}, "daily" => [{"dt" => "2023-10-07 19:00:00 UTC".to_datetime, "temp" => {"min" => 294.61, "max" => 303.82}}, {"dt" => "2023-10-08 19:00:00 UTC".to_datetime, "temp" => {"min" => 295.77, "max" => 304.76}}, {"dt" => "2023-10-09 19:00:00 UTC".to_datetime, "temp" => {"min" => 292.9, "max" => 300.5}}, {"dt" => "2023-10-10 19:00:00 UTC".to_datetime, "temp" => {"min" => 290.95, "max" => 296.3}}, {"dt" => "2023-10-11 19:00:00 UTC".to_datetime, "temp" => {"min" => 291.47, "max" => 295.51}}, {"dt" => "2023-10-12 19:00:00 UTC".to_datetime, "temp" => {"min" => 290.68, "max" => 296.23}}, {"dt" => "2023-10-13 19:00:00 UTC".to_datetime, "temp" => {"min" => 291.02, "max" => 296.48}}, {"dt" => "2023-10-14 19:00:00 UTC".to_datetime, "temp" => {"min" => 290.71, "max" => 296.79}}]}, true]
    end

    now = Time.now
    @expected_fahrenheit_data = {current_temp: 87, cached_at: now, days: [{day_label: "Sat 07", low: 71, high: 87}, {day_label: "Sun 08", low: 73, high: 89}, {day_label: "Mon 09", low: 68, high: 81}, {day_label: "Tue 10", low: 64, high: 74}, {day_label: "Wed 11", low: 65, high: 72}, {day_label: "Thu 12", low: 64, high: 74}, {day_label: "Fri 13", low: 64, high: 74}, {day_label: "Sat 14", low: 64, high: 75}], retrieved_from_cache: false}

    @expected_celsius_data = {current_temp: 31, cached_at: now, days: [{day_label: "Sat 07", low: 21, high: 31}, {day_label: "Sun 08", low: 23, high: 32}, {day_label: "Mon 09", low: 20, high: 27}, {day_label: "Tue 10", low: 18, high: 23}, {day_label: "Wed 11", low: 18, high: 22}, {day_label: "Thu 12", low: 18, high: 23}, {day_label: "Fri 13", low: 18, high: 23}, {day_label: "Sat 14", low: 18, high: 24}], retrieved_from_cache: false}
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

    @expected_fahrenheit_data[:retrieved_from_cache] = true
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
    def OpenWeatherClient.download_raw_data(opts)
      [{}, false]
    end

    data, success = OpenWeatherClient.retrieve_weather(latitude: 200, longitude: 200, city: "Chula Vista", state: "CA", zipcode: "91913", country: "US", temp_unit: "fahrenheit")
    assert_equal [{}, false], [data, success]
  end
end

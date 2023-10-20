# frozen_string_literal: true

require "test_helper"

class WeatherDataRetrieverTest < ActiveSupport::TestCase
  class TestModel
    include WeatherDataRetriever
    weather_data_attribute :weather_data, "dummy-api-key"
  end

  class ModuleTest < ActiveSupport::TestCase
    test "valid_time_string? returns true if time string is valid, false otherwise" do
      assert WeatherDataRetriever.valid_time_string?("2023-09-07 19:00:00 UTC")
      refute WeatherDataRetriever.valid_time_string?(nil)
      refute WeatherDataRetriever.valid_time_string?("")
      refute WeatherDataRetriever.valid_time_string?("foo")
      refute WeatherDataRetriever.valid_time_string?("2023")
    end
  end

  class WeatherDataSuccessTest < ActiveSupport::TestCase
    setup do
      Rails.cache.clear
      Time.zone = "Eastern Time (US & Canada)"
      Timecop.freeze(Time.zone.local(2023, 9, 1, 12, 0, 0))
      @model = TestModel.new
      @request_opts = {latitude: 32.6502944, longitude: -116.983784, city: "Chula Vista", state: "CA",
                       zipcode: "91913", country: "US", temp_unit: "fahrenheit"}
    end

    teardown do
      Timecop.return
    end

    def around(&block)
      stub_successful_open_weather_response(&block)
    end

    test "retrieves valid weather data" do
      assert @model.weather_data.retrieve(@request_opts)
      assert @model.weather_data.valid?
    end

    test "retrieves cached result on second request" do
      assert @model.weather_data.retrieve(@request_opts)
      assert @model.weather_data.valid?
      refute @model.weather_data.retrieved_from_cache?
      assert @model.weather_data.retrieve(@request_opts)
      assert @model.weather_data.valid?
      assert @model.weather_data.retrieved_from_cache?
    end

    test "when corrupted data in cache, re-retrieves data from open-weather" do
      assert @model.weather_data.retrieve(@request_opts)
      assert @model.weather_data.valid?
      refute @model.weather_data.retrieved_from_cache?
      cache_key = @model.weather_data.send(:cache_key, @request_opts)
      cache_data = Rails.cache.read(cache_key)
      assert cache_data.present?

      # generate corrupted data
      hash = JSON.parse(cache_data)

      corrupted_data_last_day_removed = hash.deep_dup
      corrupted_data_last_day_removed["forecast_days"] = hash["forecast_days"].first(6)

      corrupted_data_last_day_null = hash.deep_dup
      corrupted_data_last_day_null["forecast_days"] = hash["forecast_days"].first(6) + [nil]

      corrupted_data_missing_date = hash.deep_dup
      corrupted_data_missing_date["forecast_days"].last.delete("date")

      corrupted_data_invalid_temp = hash.deep_dup
      corrupted_data_invalid_temp["forecast_days"].last[:high_celsius] = 150
      [
        nil,
        "}{ invalid json",
        nil.to_json,
        "not a hash".to_json,
        corrupted_data_last_day_removed.to_json,
        corrupted_data_last_day_null.to_json,
        corrupted_data_missing_date.to_json,
        corrupted_data_invalid_temp.to_json
      ].each do |corrupted_data|
        Rails.cache.write(cache_key, corrupted_data, expires_in: WeatherDataRetriever::WEATHER_CACHE_EXPIRATION)

        assert @model.weather_data.retrieve(@request_opts)
        assert @model.weather_data.valid?
        refute @model.weather_data.retrieved_from_cache?
      end
    end

    test "should fail gracefully when required field is missing" do
      refute @model.weather_data.retrieve(@request_opts.except(:latitude))
      refute @model.weather_data.valid?
    end

    test "current_temp returns the correct value" do
      assert_nil @model.weather_data.current_temp("fahrenheit")
      assert @model.weather_data.retrieve(@request_opts)
      assert_equal 87, @model.weather_data.current_temp
      assert_equal 87, @model.weather_data.current_temp("fahrenheit")
      assert_equal 31, @model.weather_data.current_temp("celsius")
    end

    test "success, downloaded_at_as_time_of_day returns the correct value in the specified time zone" do
      assert_nil @model.weather_data.downloaded_at_as_time_of_day
      assert @model.weather_data.retrieve(@request_opts)
      assert_equal "9:00am PDT", @model.weather_data.downloaded_at_as_time_of_day("Pacific Time (US & Canada)")
      assert_equal "10:00am MDT", @model.weather_data.downloaded_at_as_time_of_day("Mountain Time (US & Canada)")
    end

    test "current_day returns the correct value" do
      assert @model.weather_data.retrieve(@request_opts)
      day = @model.weather_data.current_day
      assert_equal "Sat 02", day.day_label
      assert_equal 71, day.low
      assert_equal 71, day.low("fahrenheit")
      assert_equal 22, day.low("celsius")
      assert_equal 89, day.high
      assert_equal 89, day.high("fahrenheit")
      assert_equal 32, day.high("celsius")
    end

    test "forecast_days returns the correct value" do
      assert @model.weather_data.retrieve(@request_opts)
      days = @model.weather_data.forecast_days
      assert_equal 7, days.size
      day = days.first
      assert_equal "Sun 03", day.day_label
      assert_equal 73, day.low
      assert_equal 73, day.low("fahrenheit")
      assert_equal 23, day.low("celsius")
      assert_equal 89, day.high
      assert_equal 89, day.high("fahrenheit")
      assert_equal 32, day.high("celsius")
      day = days.last
      assert_equal "Sat 09", day.day_label
      assert_equal 64, day.low
      assert_equal 64, day.low("fahrenheit")
      assert_equal 18, day.low("celsius")
      assert_equal 74, day.high
      assert_equal 74, day.high("fahrenheit")
      assert_equal 24, day.high("celsius")
    end

    test "valid? returns true if all required component of data present, false otherwise" do
      weather_data = @model.weather_data
      assert weather_data.retrieve(@request_opts)
      assert weather_data.valid?

      assert weather_data.retrieve(@request_opts)
      weather_data.instance_variable_set(:@forecast_days, nil)
      refute weather_data.valid?

      assert weather_data.retrieve(@request_opts)
      weather_data.instance_variable_set(:@forecast_days, [])
      refute weather_data.valid?

      # remove last item from forecast data
      assert weather_data.retrieve(@request_opts)
      days = weather_data.instance_variable_get(:@forecast_days)
      days.pop
      refute weather_data.valid?
    end
  end

  class WeatherDataFaulureTest < ActiveSupport::TestCase
    setup do
      Rails.cache.clear
      Time.zone = "Eastern Time (US & Canada)"
      Timecop.freeze(Time.zone.local(2023, 9, 1, 12, 0, 0))
      @model = TestModel.new
      @request_opts = {latitude: 32.6502944, longitude: -116.983784, city: "Chula Vista", state: "CA",
                       zipcode: "91913", country: "US", temp_unit: "fahrenheit"}
    end

    teardown do
      Timecop.return
    end

    test "fails gracefully when OpenWeather API returns 4xx or 5xx errors" do
      [404, 407, 500, 502].each do |code|
        stub_failed_open_weather_response(code) do
          refute @model.weather_data.retrieve(@request_opts)
          refute @model.weather_data.valid?
        end
      end
    end
  end
end

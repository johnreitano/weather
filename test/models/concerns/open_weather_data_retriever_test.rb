require "test_helper"

class OpenWeatherDataRetrieverTest < ActiveSupport::TestCase
  class TestModel
    include OpenWeatherDataRetriever
    open_weather_data :weather_data
  end

  class ModuleTest < ActiveSupport::TestCase
    test "valid_time_string? returns true if time string is valid, false otherwise" do
      assert OpenWeatherDataRetriever.valid_time_string?("2023-10-07 19:00:00 UTC")
      refute OpenWeatherDataRetriever.valid_time_string?(nil)
      refute OpenWeatherDataRetriever.valid_time_string?("")
      refute OpenWeatherDataRetriever.valid_time_string?("foo")
      refute OpenWeatherDataRetriever.valid_time_string?("2023")
    end
  end

  class WeatherDataTest < ActiveSupport::TestCase
    setup do
      Rails.cache.clear

      Time.zone = "Eastern Time (US & Canada)"
      Timecop.freeze(Time.zone.local(2023, 9, 1, 12, 0, 0))

      @model = TestModel.new

      # stub for returning data in successful scenarios
      weather_data = @model.weather_data
      def weather_data.open_weather_client(api_key)
        mock_client = Object.new
        def mock_client.one_call(opts)
          {"current" => {"temp" => 303.82}, "daily" => [{"dt" => "2023-10-07 19:00:00 UTC".to_time, "temp" => {"min" => 294.61, "max" => 304.82}}, {"dt" => "2023-10-08 19:00:00 UTC".to_time, "temp" => {"min" => 295.77, "max" => 304.76}}, {"dt" => "2023-10-09 19:00:00 UTC".to_time, "temp" => {"min" => 292.9, "max" => 300.5}}, {"dt" => "2023-10-10 19:00:00 UTC".to_time, "temp" => {"min" => 290.95, "max" => 296.3}}, {"dt" => "2023-10-11 19:00:00 UTC".to_time, "temp" => {"min" => 291.47, "max" => 295.51}}, {"dt" => "2023-10-12 19:00:00 UTC".to_time, "temp" => {"min" => 290.68, "max" => 296.23}}, {"dt" => "2023-10-13 19:00:00 UTC".to_time, "temp" => {"min" => 291.02, "max" => 296.48}}, {"dt" => "2023-10-14 19:00:00 UTC".to_time, "temp" => {"min" => 290.71, "max" => 296.79}}]}
        end
        mock_client
      end

      @request_opts = {latitude: 32.6502944, longitude: -116.983784, city: "Chula Vista", state: "CA", zipcode: "91913", country: "US", temp_unit: "fahrenheit", open_weather_api_key: "123"}
    end

    teardown do
      Timecop.return
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

      [
        nil,
        "",
        "invalid_data",

        # last day is null
        "{\"current_temp_celsius\":30.7,\"downloaded_at\":\"2023-09-01T09:00:00.000-07:00\",\"current_day\":{\"date\":\"2023-10-07T19:00:00.000+00:00\",\"low_celsius\":21.5,\"high_celsius\":31.7},\"forecast_days\":[{\"date\":\"2023-10-08T19:00:00.000+00:00\",\"low_celsius\":22.6,\"high_celsius\":31.6},{\"date\":\"2023-10-09T19:00:00.000+00:00\",\"low_celsius\":19.8,\"high_celsius\":27.4},{\"date\":\"2023-10-10T19:00:00.000+00:00\",\"low_celsius\":17.8,\"high_celsius\":23.2},{\"date\":\"2023-10-11T19:00:00.000+00:00\",\"low_celsius\":18.3,\"high_celsius\":22.4},{\"date\":\"2023-10-12T19:00:00.000+00:00\",\"low_celsius\":17.5,\"high_celsius\":23.1},{\"date\":\"2023-10-13T19:00:00.000+00:00\",\"low_celsius\":17.9,\"high_celsius\":23.3},null]}",

        # missing date on last day
        "{\"current_temp_celsius\":30.7,\"downloaded_at\":\"2023-09-01T09:00:00.000-07:00\",\"current_day\":{\"date\":\"2023-10-07T19:00:00.000+00:00\",\"low_celsius\":21.5,\"high_celsius\":31.7},\"forecast_days\":[{\"date\":\"2023-10-08T19:00:00.000+00:00\",\"low_celsius\":22.6,\"high_celsius\":31.6},{\"date\":\"2023-10-09T19:00:00.000+00:00\",\"low_celsius\":19.8,\"high_celsius\":27.4},{\"date\":\"2023-10-10T19:00:00.000+00:00\",\"low_celsius\":17.8,\"high_celsius\":23.2},{\"date\":\"2023-10-11T19:00:00.000+00:00\",\"low_celsius\":18.3,\"high_celsius\":22.4},{\"date\":\"2023-10-12T19:00:00.000+00:00\",\"low_celsius\":17.5,\"high_celsius\":23.1},{\"date\":\"2023-10-13T19:00:00.000+00:00\",\"low_celsius\":17.9,\"high_celsius\":23.3},{\"low_celsius\":17.6,\"high_celsius\":23.6}]}",

        # invalid temp on last day
        "{\"current_temp_celsius\":30.7,\"downloaded_at\":\"2023-09-01T09:00:00.000-07:00\",\"current_day\":{\"date\":\"2023-10-07T19:00:00.000+00:00\",\"low_celsius\":21.5,\"high_celsius\":31.7},\"forecast_days\":[{\"date\":\"2023-10-08T19:00:00.000+00:00\",\"low_celsius\":22.6,\"high_celsius\":31.6},{\"date\":\"2023-10-09T19:00:00.000+00:00\",\"low_celsius\":19.8,\"high_celsius\":27.4},{\"date\":\"2023-10-10T19:00:00.000+00:00\",\"low_celsius\":17.8,\"high_celsius\":23.2},{\"date\":\"2023-10-11T19:00:00.000+00:00\",\"low_celsius\":18.3,\"high_celsius\":22.4},{\"date\":\"2023-10-12T19:00:00.000+00:00\",\"low_celsius\":17.5,\"high_celsius\":23.1},{\"date\":\"2023-10-13T19:00:00.000+00:00\",\"low_celsius\":17.9,\"high_celsius\":23.3},{\"date\":\"2023-10-14T19:00:00.000+00:00\",\"low_celsius\":17.6,\"high_celsius\":123.6}]}"
      ].each do |bad_data|
        key = @model.weather_data.send(:cache_key, @request_opts)
        Rails.cache.write(key, bad_data, expires_in: OpenWeatherDataRetriever::WEATHER_CACHE_EXPIRATION)
        assert @model.weather_data.retrieve(@request_opts)
        assert @model.weather_data.valid?
        refute @model.weather_data.retrieved_from_cache?
      end
    end

    test "should fail gracefully when required field is missing" do
      refute @model.weather_data.retrieve(@request_opts.except(:latitude))
      refute @model.weather_data.valid?
    end

    test "fails gracefully when OpenWeather returns exception" do
      # simulate OpenWeather api raising an OpenWeather::Errors::Fault exception
      weather_data = @model.weather_data
      def weather_data.open_weather_client(api_key)
        mock_client = Object.new
        def mock_client.one_call(opts)
          raise OpenWeather::Errors::Fault.new "dummy exception"
        end
        mock_client
      end
      refute @model.weather_data.retrieve(@request_opts)
      refute @model.weather_data.valid?
    end

    test "fails gracefully when network connection fails" do
      # simulate network exception
      weather_data = @model.weather_data
      def weather_data.open_weather_client(api_key)
        mock_client = Object.new
        def mock_client.one_call(opts)
          raise Faraday::ConnectionFailed.new "dummy exception"
        end
        mock_client
      end
      refute @model.weather_data.retrieve(@request_opts)
      refute @model.weather_data.valid?
    end

    test "after success, current_temp returns the correct value" do
      assert_nil @model.weather_data.current_temp("fahrenheit")
      assert @model.weather_data.retrieve(@request_opts)
      assert_equal 87, @model.weather_data.current_temp
      assert_equal 87, @model.weather_data.current_temp("fahrenheit")
      assert_equal 31, @model.weather_data.current_temp("celsius")
    end

    test "after success, downloaded_at_as_time_of_day returns the correct value in the specified time zone" do
      assert_nil @model.weather_data.downloaded_at_as_time_of_day
      assert @model.weather_data.retrieve(@request_opts)
      assert_equal "9:00am PDT", @model.weather_data.downloaded_at_as_time_of_day("Pacific Time (US & Canada)")
      assert_equal "10:00am MDT", @model.weather_data.downloaded_at_as_time_of_day("Mountain Time (US & Canada)")
    end

    test "current_day returns the correct value" do
      assert @model.weather_data.retrieve(@request_opts)
      day = @model.weather_data.current_day
      assert_equal "Sat 07", day.day_label
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
      assert_equal "Sun 08", day.day_label
      assert_equal 73, day.low
      assert_equal 73, day.low("fahrenheit")
      assert_equal 23, day.low("celsius")
      assert_equal 89, day.high
      assert_equal 89, day.high("fahrenheit")
      assert_equal 32, day.high("celsius")
      day = days.last
      assert_equal "Sat 14", day.day_label
      assert_equal 64, day.low
      assert_equal 64, day.low("fahrenheit")
      assert_equal 18, day.low("celsius")
      assert_equal 75, day.high
      assert_equal 75, day.high("fahrenheit")
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
end

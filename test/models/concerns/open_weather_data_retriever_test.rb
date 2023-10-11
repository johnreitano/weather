require "test_helper"

class OpenWeatherDataRetrieverTest < ActiveSupport::TestCase
  class TestModel
    include OpenWeatherDataRetriever
  end

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
        {"current" => {"temp" => 303.82}, "daily" => [{"dt" => "2023-10-07 19:00:00 UTC".to_datetime, "temp" => {"min" => 294.61, "max" => 304.82}}, {"dt" => "2023-10-08 19:00:00 UTC".to_datetime, "temp" => {"min" => 295.77, "max" => 304.76}}, {"dt" => "2023-10-09 19:00:00 UTC".to_datetime, "temp" => {"min" => 292.9, "max" => 300.5}}, {"dt" => "2023-10-10 19:00:00 UTC".to_datetime, "temp" => {"min" => 290.95, "max" => 296.3}}, {"dt" => "2023-10-11 19:00:00 UTC".to_datetime, "temp" => {"min" => 291.47, "max" => 295.51}}, {"dt" => "2023-10-12 19:00:00 UTC".to_datetime, "temp" => {"min" => 290.68, "max" => 296.23}}, {"dt" => "2023-10-13 19:00:00 UTC".to_datetime, "temp" => {"min" => 291.02, "max" => 296.48}}, {"dt" => "2023-10-14 19:00:00 UTC".to_datetime, "temp" => {"min" => 290.71, "max" => 296.79}}]}
      end
      mock_client
    end

    @request_opts = {latitude: 32.6502944, longitude: -116.983784, city: "Chula Vista", state: "CA", zipcode: "91913", country: "US", temp_unit: "fahrenheit", open_weather_api_key: "123"}

    @expected_celsius_data = {current_temp: 30.7, cached_at: Time.now, days: [{day_label: "Sat 07", low: 21.5, high: 31.7}, {day_label: "Sun 08", low: 22.6, high: 31.6}, {day_label: "Mon 09", low: 19.8, high: 27.4}, {day_label: "Tue 10", low: 17.8, high: 23.2}, {day_label: "Wed 11", low: 18.3, high: 22.4}, {day_label: "Thu 12", low: 17.5, high: 23.1}, {day_label: "Fri 13", low: 17.9, high: 23.3}, {day_label: "Sat 14", low: 17.6, high: 23.6}], retrieved_from_cache: false}
  end

  teardown do
    Timecop.return
  end

  test "retrieve weather data" do
    assert @model.weather_data.retrieve(@request_opts)
    assert @model.weather_data.available?
    assert_equal @expected_celsius_data, @model.weather_data.instance_variable_get(:@retrieved_data)
  end

  test "should return cached result on second request" do
    assert @model.weather_data.retrieve(@request_opts)
    assert @model.weather_data.available?
    refute @model.weather_data.retrieved_from_cache?
    assert @model.weather_data.retrieve(@request_opts)
    assert @model.weather_data.available?
    assert @model.weather_data.retrieved_from_cache?
  end

  test "should fail gracefully when required field is missing" do
    refute @model.weather_data.retrieve(@request_opts.except(:latitude))
    refute @model.weather_data.available?
  end

  test "should fail gracefully when OpenWeather returns exception" do
    # simulate OpenWeather api raising an exception
    weather_data = @model.weather_data
    def weather_data.open_weather_client(api_key)
      mock_client = Object.new
      def mock_client.one_call(opts)
        raise OpenWeather::Errors::Fault.new "dummy exception"
      end
      mock_client
    end
    refute @model.weather_data.retrieve(@request_opts)
    refute @model.weather_data.available?
  end

  test "current_temp returns the correct value" do
    assert_nil @model.weather_data.current_temp
    assert @model.weather_data.retrieve(@request_opts)
    assert_equal 87.3, @model.weather_data.current_temp
  end

  test "cached_at returns the correct value in Pacific Time" do
    assert_nil @model.weather_data.cached_at
    assert @model.weather_data.retrieve(@request_opts)
    assert_equal "9:00am PDT", @model.weather_data.cached_at
  end

  test "current_day_low returns the correct value" do
    assert_nil @model.weather_data.current_day_low
    assert @model.weather_data.retrieve(@request_opts)
    assert_equal 70.7, @model.weather_data.current_day_low
  end

  test "current_day_high returns the correct value" do
    assert_nil @model.weather_data.current_day_high
    assert @model.weather_data.retrieve(@request_opts)
    assert_equal 89.1, @model.weather_data.current_day_high
  end

  test "day_* methods return correct values" do
    assert_nil @model.weather_data.day_label(1)
    assert_nil @model.weather_data.day_low(1)
    assert_nil @model.weather_data.day_high(1)

    assert @model.weather_data.retrieve(@request_opts)
    assert_equal "Sun 08", @model.weather_data.day_label(1)
    assert_equal "Mon 09", @model.weather_data.day_label(2)
    assert_equal 72.7, @model.weather_data.day_low(1)
    assert_equal 67.6, @model.weather_data.day_low(2)
    assert_equal 88.9, @model.weather_data.day_high(1)
    assert_equal 81.3, @model.weather_data.day_high(2)
  end

  test "available? returns true if all required component of data present, false otherwise" do
    complete_weather_data = {current_temp: 87.2, cached_at: Time.now, days: [{day_label: "Sat 07", low: 70.6, high: 87.2}, {day_label: "Sun 08", low: 72.7, high: 88.9}, {day_label: "Mon 09", low: 67.6, high: 81.2}, {day_label: "Tue 10", low: 64.0, high: 73.7}, {day_label: "Wed 11", low: 65.0, high: 72.3}, {day_label: "Thu 12", low: 63.6, high: 73.5}, {day_label: "Fri 13", low: 64.2, high: 74.0}, {day_label: "Sat 14", low: 63.6, high: 74.6}], retrieved_from_cache: false}

    weather_data = @model.weather_data
    assert weather_data.retrieve(@request_opts)
    assert weather_data.available?

    weather_data.instance_variable_set(:@retrieved_data, complete_weather_data.except(:current_temp))
    refute weather_data.available?

    weather_data.instance_variable_set(:@retrieved_data, complete_weather_data.except(:cached_at))
    refute weather_data.available?

    weather_data.instance_variable_set(:@retrieved_data, complete_weather_data.except(:days))
    refute weather_data.available?

    weather_data.instance_variable_set(:@retrieved_data, complete_weather_data.merge(days: []))
    refute weather_data.available?

    # remove last item from forecast data
    partial_weather_data = complete_weather_data.dup
    partial_weather_data[:days].pop
    weather_data.instance_variable_set(:@weather_data, partial_weather_data)
    refute weather_data.available?
  end
end

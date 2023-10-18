# OpenWeatherDataRetriever can be included in any ruby model to add the ability to retrieve
# data from the Open Weather API. See https://openweathermap.org/api for details on the source data.
# To use this module, add the following two lines to your model class:
#
#   include OpenWeatherDataRetriever
#   open_weather_data :weather_data
#
module OpenWeatherDataRetriever
  extend ActiveSupport::Concern
  WEATHER_CACHE_EXPIRATION = 30.minutes
  ZERO_CELSIUS_IN_KELVIN = 273.15

  included do
    def self.open_weather_data(field_name)
      @weather_data_field_name = field_name.to_sym
      attr_reader @weather_data_field_name
    end
  end

  def initialize(*args)
    super
    field_name = self.class.instance_variable_get(:@weather_data_field_name)
    instance_variable_set("@#{field_name}", WeatherData.new)
  end

  def self.valid_celsius_temp?(temp)
    temp.in?(-100.0..100.0)
  end

  def self.to_fahrenheit_or_celsius(temp_celsius, temp_unit)
    return nil if temp_celsius.nil?
    temp = if temp_unit&.to_s&.downcase == "celsius"
      temp_celsius
    else
      (temp_celsius.to_f * 9.0 / 5.0 + 32.0).round(1)
    end
    temp.round
  end

  def self.valid_time_string?(str)
    unless str.is_a?(String) && str.present?
      Rails.logger.warn("time not a string: #{str}")
      return false
    end
    begin
      Time.parse(str)
    rescue ArgumentError
      Rails.logger.warn("time string not a valid time: #{str}")
      return false
    end
    true
  end

  class WeatherDay
    attr_reader :date, :low_celsius, :high_celsius

    def initialize(date:, low_celsius:, high_celsius:)
      @date = if date.is_a?(String) && OpenWeatherDataRetriever.valid_time_string?(date)
        Time.parse(date)
      else
        date
      end
      @low_celsius = low_celsius
      @high_celsius = high_celsius
    end

    def as_json(options = {})
      {date: date, low_celsius: low_celsius, high_celsius: high_celsius}
    end

    def day_label
      date.strftime("%a %d")
    end

    def low(temp_unit = "fahrenheit")
      OpenWeatherDataRetriever.to_fahrenheit_or_celsius(low_celsius, temp_unit)
    end

    def high(temp_unit = "fahrenheit")
      OpenWeatherDataRetriever.to_fahrenheit_or_celsius(high_celsius, temp_unit)
    end

    def valid?
      date.is_a?(Time) && OpenWeatherDataRetriever.valid_celsius_temp?(low_celsius) && OpenWeatherDataRetriever.valid_celsius_temp?(high_celsius)
    end
  end

  class WeatherData
    attr_reader :downloaded_at, :current_day, :forecast_days, :retrieved_from_cache

    def initialize
      reinitialize
    end

    def retrieve(opts)
      reinitialize
      return false unless all_required_opts_present?(opts)
      retrieve_data_from_cache_or_open_weather(opts)
    end

    def valid?
      OpenWeatherDataRetriever.valid_celsius_temp?(@current_temp_celsius) && downloaded_at.is_a?(Time) && current_day.is_a?(OpenWeatherDataRetriever::WeatherDay) && forecast_days.is_a?(Array) && forecast_days.length == 7 && forecast_days.all? { |day| day.is_a?(OpenWeatherDataRetriever::WeatherDay) && day.valid? } && retrieved_from_cache.in?([true, false])
    end

    def retrieved_from_cache?
      !!retrieved_from_cache
    end

    def current_temp(temp_unit = "fahrenheit")
      OpenWeatherDataRetriever.to_fahrenheit_or_celsius(@current_temp_celsius, temp_unit)
    end

    def downloaded_at_as_time_of_day(time_zone = "Pacific Time (US & Canada)")
      downloaded_at&.in_time_zone(time_zone)&.strftime("%l:%M%P %Z")&.strip
    end

    def as_json(options = {})
      {
        current_temp_celsius: @current_temp_celsius,
        downloaded_at: downloaded_at,
        current_day: current_day.as_json,
        forecast_days: forecast_days.as_json
      }
    end

    private

    def reinitialize
      @downloaded_at = nil
      @forecast_days = []
      @current_day = WeatherDay.new(date: nil, low_celsius: nil, high_celsius: nil)
    end

    def valid_cached_day_hash?(day_hash)
      unless day_hash.is_a?(Hash)
        Rails.logger.warn("day does not contain a hash")
        return false
      end

      OpenWeatherDataRetriever.valid_time_string?(day_hash["date"]) && OpenWeatherDataRetriever.valid_celsius_temp?(day_hash["low_celsius"]) && OpenWeatherDataRetriever.valid_celsius_temp?(day_hash["high_celsius"])
    end

    def valid_cache_data_hash?(hash)
      valid = hash["current_temp_celsius"].present? &&
        OpenWeatherDataRetriever.valid_time_string?(hash["downloaded_at"]) &&
        valid_cached_day_hash?(hash["current_day"]) &&
        hash["forecast_days"].is_a?(Array) && hash["forecast_days"].length == 7 &&
        hash["forecast_days"].all? { |day_hash| valid_cached_day_hash?(day_hash) }
      Rails.logger.warn("invalid cache data: #{hash}") unless valid
      valid
    end

    def open_weather_data_valid?(open_weather_data)
      days = open_weather_data["daily"]
      unless valid_kelvin_temp?(open_weather_data.dig("current", "temp")) &&
          days.is_a?(Array) &&
          days.length >= 8 &&
          days.all? { |day_hash| valid_open_weather_day_hash?(day_hash) }
        Rails.logger.warn("invalid open weather data: #{open_weather_data}")
        return false
      end
      true
    end

    def valid_open_weather_day_hash?(day_hash)
      day_hash.is_a?(Hash) &&
        day_hash["dt"].is_a?(Time) &&
        valid_kelvin_temp?(day_hash.dig("temp", "min")) &&
        valid_kelvin_temp?(day_hash.dig("temp", "max"))
    end

    def valid_kelvin_temp?(temp)
      valid = temp.in?(173.15..373.15)
      Rails.logger.warn("invalid kelvin temperature: #{temp}") unless valid
      valid
    end

    def cache_data_as_hash(str)
      JSON.parse(str)
    rescue JSON::ParserError
      Rails.logger.warn("cache data does not contain valid JSON: #{str}")
      {}
    end

    def parse_cache_data(str)
      hash = cache_data_as_hash(str)
      return false unless valid_cache_data_hash?(hash)

      @current_temp_celsius = hash["current_temp_celsius"]
      @downloaded_at = Time.parse(hash["downloaded_at"])
      day_hash = hash["current_day"]
      @current_day = OpenWeatherDataRetriever::WeatherDay.new(
        date: day_hash["date"],
        low_celsius: day_hash["low_celsius"],
        high_celsius: day_hash["high_celsius"]
      )
      days = hash["forecast_days"]
      @forecast_days = days.map do |day_hash|
        OpenWeatherDataRetriever::WeatherDay.new(
          date: day_hash["date"],
          low_celsius: day_hash["low_celsius"],
          high_celsius: day_hash["high_celsius"]
        )
      end
      true
    end

    def all_required_opts_present?(opts)
      %w[latitude longitude zipcode country open_weather_api_key].all? do |key|
        if opts[key.to_sym].present?
          true
        else
          Rails.logger.warn("missing value for required option #{key}")
          false
        end
      end
    end

    def cache_key(opts)
      "OPENWEATHER/#{opts[:city]}/#{opts[:state]}/#{opts[:zipcode]}/#{opts[:country]}"
    end

    def open_weather_client(api_key)
      @open_weather_client ||= OpenWeather::Client.new(api_key: api_key)
    end

    def retrieve_data_from_open_weather(opts)
      open_weather_data = download_open_weather_data(opts)
      parse_open_weather_data(open_weather_data)
    end

    def download_open_weather_data(opts)
      client = open_weather_client(opts[:open_weather_api_key])
      client.one_call(lat: opts[:latitude], lon: opts[:longitude])
    rescue OpenWeather::Errors::Fault => e
      Rails.logger.warn("received fault from OpenWeather: #{e}")
      {}
    rescue Faraday::ConnectionFailed => e
      Rails.logger.warn("received connection failed error when attempting to connect to OpenWeather: #{e}")
      {}
    end

    def parse_open_weather_data(open_weather_data)
      return false unless open_weather_data_valid?(open_weather_data)

      @current_temp_celsius = kelvin_to_celsius(open_weather_data.dig("current", "temp"))
      @downloaded_at = Time.now
      weather_days = open_weather_data["daily"].first(8).map do |day_info|
        OpenWeatherDataRetriever::WeatherDay.new(
          date: day_info["dt"],
          low_celsius: kelvin_to_celsius(day_info.dig("temp", "min")),
          high_celsius: kelvin_to_celsius(day_info.dig("temp", "max"))
        )
      end
      @current_day = weather_days[0]
      @forecast_days = weather_days[1..7]
      true
    end

    def retrieve_data_from_cache(opts)
      cache_data = Rails.cache.read(cache_key(opts))
      return false unless cache_data
      parse_cache_data(cache_data)
    end

    def retrieve_data_from_cache_or_open_weather(opts)
      if retrieve_data_from_cache(opts)
        @retrieved_from_cache = true
        return true
      end

      return false unless retrieve_data_from_open_weather(opts)
      Rails.cache.write(cache_key(opts), to_json, expires_in: WEATHER_CACHE_EXPIRATION)
      @retrieved_from_cache = false
      true
    end

    def kelvin_to_celsius(temp_k)
      return nil if temp_k.nil?
      (temp_k.to_f - ZERO_CELSIUS_IN_KELVIN).round(1)
    end
  end
end

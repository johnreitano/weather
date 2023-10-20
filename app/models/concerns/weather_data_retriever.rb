# frozen_string_literal: true

# WeatherDataRetriever can be included in any ruby model to add the ability to retrieve
# data from the Open Weather API. See https://openweathermap.org/api for details on the source data.
# To use this module, add the following two lines to your model class:
#
#   include WeatherDataRetriever
#   weather_data_attribute :weather_data, "put-open-weather-api-key-here"
#
module WeatherDataRetriever
  extend ActiveSupport::Concern
  WEATHER_CACHE_EXPIRATION = 30.minutes
  ZERO_CELSIUS_IN_KELVIN = 273.15

  included do
    def self.weather_data_attribute(attribute_name, api_key)
      @weather_data_attribute_name = attribute_name.to_sym
      @api_key = api_key
      attr_reader @weather_data_attribute_name
    end
  end

  def initialize(*)
    super
    attribute_name = self.class.instance_variable_get(:@weather_data_attribute_name)
    api_key = self.class.instance_variable_get(:@api_key)
    instance_variable_set("@#{attribute_name}", WeatherData.new(api_key))
  end

  def self.valid_celsius_temp?(temp)
    temp.in?(-100.0..100.0)
  end

  def self.to_fahrenheit_or_celsius(temp_celsius, temp_unit)
    return nil if temp_celsius.nil?

    temp = celsius?(temp_unit) ? temp_celsius : celsius_to_fahrenheit(temp_celsius)
    temp.round
  end

  def self.celsius?(temp_unit)
    temp_unit.to_s.downcase == "celsius"
  end

  def self.celsius_to_fahrenheit(temp_celsius)
    temp_celsius.to_f * 9.0 / 5.0 + 32.0
  end

  def self.valid_time_string?(str)
    return false unless str.is_a?(String)
    begin
      Time.parse(str.to_s)
      true
    rescue ArgumentError
      Rails.logger.warn("time string not a valid time: #{str}")
      false
    end
  end

  class WeatherDay
    attr_reader :date, :low_celsius, :high_celsius

    def initialize(date:, low_celsius:, high_celsius:)
      @date = if WeatherDataRetriever.valid_time_string?(date)
        Time.parse(date)
      else
        date
      end
      @low_celsius = low_celsius
      @high_celsius = high_celsius
    end

    def as_json(_options = {})
      {date:, low_celsius:, high_celsius:}
    end

    def day_label
      date.strftime("%a %d")
    end

    def low(temp_unit = "fahrenheit")
      WeatherDataRetriever.to_fahrenheit_or_celsius(low_celsius, temp_unit)
    end

    def high(temp_unit = "fahrenheit")
      WeatherDataRetriever.to_fahrenheit_or_celsius(high_celsius, temp_unit)
    end

    def valid?
      date.is_a?(Time) && WeatherDataRetriever.valid_celsius_temp?(low_celsius) && WeatherDataRetriever.valid_celsius_temp?(high_celsius)
    end
  end

  class WeatherData
    attr_reader :downloaded_at, :current_day, :forecast_days, :retrieved_from_cache

    def initialize(api_key)
      @api_key = api_key
      reinitialize
    end

    def retrieve(opts)
      reinitialize
      return false unless all_required_opts_present?(opts)

      retrieve_data_from_cache_or_open_weather(opts)
    end

    def valid?
      WeatherDataRetriever.valid_celsius_temp?(@current_temp_celsius) && downloaded_at.is_a?(Time) && current_day.is_a?(WeatherDataRetriever::WeatherDay) && forecast_days.is_a?(Array) && forecast_days.length == 7 && forecast_days.all? do |day|
        day.is_a?(WeatherDataRetriever::WeatherDay) && day.valid?
      end && retrieved_from_cache.in?([true, false])
    end

    def retrieved_from_cache?
      !!retrieved_from_cache
    end

    def current_temp(temp_unit = "fahrenheit")
      WeatherDataRetriever.to_fahrenheit_or_celsius(@current_temp_celsius, temp_unit)
    end

    def downloaded_at_as_time_of_day(time_zone = "Pacific Time (US & Canada)")
      downloaded_at&.in_time_zone(time_zone)&.strftime("%l:%M%P %Z")&.strip
    end

    def as_json(_options = {})
      {
        current_temp_celsius: @current_temp_celsius,
        downloaded_at:,
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
      valid = day_hash.is_a?(Hash) &&
        WeatherDataRetriever.valid_time_string?(day_hash["date"]) &&
        WeatherDataRetriever.valid_celsius_temp?(day_hash["low_celsius"]) &&
        WeatherDataRetriever.valid_celsius_temp?(day_hash["high_celsius"])
      Rails.logger.warn("invalid cached day hash: #{day_hash}") unless valid
      valid
    end

    def valid_cache_data_hash?(hash)
      valid = hash["current_temp_celsius"].present? &&
        WeatherDataRetriever.valid_time_string?(hash["downloaded_at"]) &&
        valid_cached_day_hash?(hash["current_day"]) &&
        hash["forecast_days"].is_a?(Array) && hash["forecast_days"].length == 7 &&
        hash["forecast_days"].all? { |day_hash| valid_cached_day_hash?(day_hash) }
      Rails.logger.warn("invalid cache data hash: #{hash}") unless valid
      valid
    end

    def valid_open_weather_day_hash?(day_hash)
      max_time = Time.now.to_i + 9.day.in_seconds
      valid = day_hash.is_a?(Hash) &&
        day_hash["dt"].is_a?(Integer) &&
        day_hash["dt"].in?(0..max_time) &&
        valid_kelvin_temp?(day_hash.dig("temp", "min")) &&
        valid_kelvin_temp?(day_hash.dig("temp", "max"))
      Rails.logger.warn("invalid open weather day hash: #{day_hash}") unless valid
      valid
    end

    def valid_open_weather_data?(weather_data)
      valid = valid_kelvin_temp?(weather_data.dig("current", "temp")) &&
        weather_data["daily"].is_a?(Array) &&
        weather_data["daily"].length >= 8 &&
        weather_data["daily"].all? { |day_hash| valid_open_weather_day_hash?(day_hash) }
      Rails.logger.warn("invalid open weather data: #{weather_data}") unless valid
      valid
    end

    def valid_kelvin_temp?(temp)
      valid = temp.in?(173.15..373.15)
      Rails.logger.warn("invalid kelvin temperature: #{temp}") unless valid
      valid
    end

    def parse_json_hash(str)
      h = JSON.parse(str)
      unless h.is_a?(Hash)
        Rails.logger.warn("json data does not contain a hash: #{str}")
        return {}
      end
      h
    rescue JSON::ParserError
      Rails.logger.warn("json data not valid: #{str}")
      {}
    end

    def parse_cache_data(str)
      hash = parse_json_hash(str)
      return false unless valid_cache_data_hash?(hash)

      @current_temp_celsius = hash["current_temp_celsius"]
      @downloaded_at = Time.parse(hash["downloaded_at"])
      day_hash = hash["current_day"]
      @current_day = WeatherDataRetriever::WeatherDay.new(
        date: day_hash["date"],
        low_celsius: day_hash["low_celsius"],
        high_celsius: day_hash["high_celsius"]
      )
      days = hash["forecast_days"]
      @forecast_days = days.map do |day_hash|
        WeatherDataRetriever::WeatherDay.new(
          date: day_hash["date"],
          low_celsius: day_hash["low_celsius"],
          high_celsius: day_hash["high_celsius"]
        )
      end
      true
    end

    def all_required_opts_present?(opts)
      %w[latitude longitude zipcode country].all? do |key|
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

    def retrieve_data_from_open_weather(opts)
      open_weather_data = download_open_weather_data(opts)
      parse_open_weather_data(open_weather_data)
    end

    def download_open_weather_data(opts)
      response = RestClient.get 'https://api.openweathermap.org/data/3.0/onecall', {
        accept: :json,
        params: {
          lat: opts[:latitude],
          lon: opts[:longitude],
          exclude: "minutely,hourly,alerts",
          appid: @api_key
        }
      }
      unless response.code.in?(200..299)
        Rails.logger.warn("received unexpected status #{response.code} from OpenWeather: #{response.body}")
        return {}
      end
      parse_json_hash(response.body)
    end

    def parse_open_weather_data(open_weather_data)
      return false unless valid_open_weather_data?(open_weather_data)

      @current_temp_celsius = kelvin_to_celsius(open_weather_data.dig("current", "temp"))
      @downloaded_at = Time.now
      weather_days = open_weather_data["daily"].first(8).map do |day_info|
        WeatherDataRetriever::WeatherDay.new(
          date: Time.at(day_info["dt"]),
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

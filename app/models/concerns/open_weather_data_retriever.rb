module OpenWeatherDataRetriever
  extend ActiveSupport::Concern
  WEATHER_CACHE_EXPIRATION = 30.minutes

  included do
    attr_reader :weather_data
  end

  def initialize(*args)
    super
    @weather_data = WeatherData.new
  end

  class WeatherData
    attr_reader :retrieved_data

    def initialize
      @retrieved_data = {}
    end

    def retrieve(opts)
      @retrieved_data = {}
      return false unless all_required_opts_present?(opts)

      @retrieved_data, success = retrieve_data_from_cache_or_open_weather(opts)
      success
    end

    def current_temp(temp_unit = "fahrenheit")
      to_faharenheit_or_celsius(retrieved_data[:current_temp], temp_unit)
    end

    def cached_at(time_zone = "Pacific Time (US & Canada)")
      retrieved_data[:cached_at]&.in_time_zone(time_zone)&.strftime("%l:%M%P %Z")&.strip
    end

    def current_day_low(temp_unit = "fahrenheit")
      day_low(0, temp_unit)
    end

    def current_day_high(temp_unit = "fahrenheit")
      day_high(0, temp_unit)
    end

    def day_label(day_index)
      day(day_index)[:day_label]
    end

    def day_low(day_index, temp_unit = "fahrenheit")
      to_faharenheit_or_celsius(day(day_index)[:low], temp_unit)
    end

    def day_high(day_index, temp_unit = "fahrenheit")
      to_faharenheit_or_celsius(day(day_index)[:high], temp_unit)
    end

    def available?
      return false unless retrieved_data.present? && retrieved_data[:current_temp].present? && retrieved_data[:cached_at].present? && retrieved_data[:days]&.length == 8
      retrieved_data[:days].all? { |d| d[:day_label].present? && d[:high].present? && d[:low].present? }
    end

    def retrieved_from_cache?
      retrieved_data[:retrieved_from_cache].present?
    end

    private

    def day(day_index)
      days = retrieved_data[:days] || []
      return {} if day_index > days.length - 1
      days[day_index]
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
      "WEATHER/#{opts[:city]}/#{opts[:state]}/#{opts[:zip]}/#{opts[:country]}"
    end

    def open_weather_client(api_key)
      @open_weather_client ||= OpenWeather::Client.new(api_key: api_key)
    end

    def download_and_format_data(opts)
      raw_data, success = download_raw_data(opts)
      return [{}, false] unless success

      [format_data(raw_data), true]
    end

    def download_raw_data(opts)
      begin
        client = open_weather_client(opts[:open_weather_api_key])
        raw_data = client.one_call(lat: opts[:latitude], lon: opts[:longitude])
      rescue OpenWeather::Errors::Fault => e
        Rails.logger.warn("received fault from OpenWeather: #{e}")
        return [{}, false]
      rescue Faraday::ConnectionFailed => e
        Rails.logger.warn("received connection failed error when attempting to connect to OpenWeather: #{e}")
        return [{}, false]
      end
      [raw_data, true]
    end

    def format_data(raw_data)
      {
        current_temp: kelvin_to_celsius(raw_data.dig("current", "temp")),
        cached_at: Time.now,
        days: raw_data["daily"][0..7].map do |day|
          {
            day_label: day["dt"].strftime("%a %d"),
            low: kelvin_to_celsius(day.dig("temp", "min")),
            high: kelvin_to_celsius(day.dig("temp", "max"))
          }
        end
      }
    end

    def retrieve_data_from_cache_or_open_weather(opts)
      key = cache_key(opts)
      cached_data = Rails.cache.read(key)
      return [cached_data.merge(retrieved_from_cache: true), true] if cached_data

      formatted_data, success = download_and_format_data(opts)
      return [{}, false] unless success

      Rails.cache.write(key, formatted_data, expires_in: WEATHER_CACHE_EXPIRATION)
      [formatted_data.merge(retrieved_from_cache: false), true]
    end

    def to_faharenheit_or_celsius(temp, temp_unit)
      temp = celsius_to_fahrenheit(temp) unless temp_unit&.to_s == "celsius"
      temp&.round(1)
    end

    ZERO_CELSIUS_IN_KELVIN = 273.15
    def kelvin_to_celsius(temp_k)
      return nil if temp_k.nil?
      (temp_k.to_f - ZERO_CELSIUS_IN_KELVIN).round(1)
    end

    def celsius_to_fahrenheit(temp_c)
      return nil if temp_c.nil?
      (temp_c.to_f * 9.0 / 5.0 + 32.0).round(1)
    end
  end
end

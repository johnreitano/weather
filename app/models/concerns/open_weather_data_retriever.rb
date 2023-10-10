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
    attr_reader :formatted_data

    def initialize
      @formatted_data = {}
    end

    def retrieve(opts)
      @formatted_data = {}

      return false unless all_required_opts_present?(opts)

      unformatted_data, success = retrieve_unformatted_data(opts)
      return false unless success

      @formatted_data = format_temps(unformatted_data, opts[:temp_unit])
      true
    end

    def current_temp
      formatted_data[:current_temp]
    end

    def cached_at
      # TODO: move this to format_temps
      t = formatted_data[:cached_at]
      return nil unless t
      t = t.in_time_zone("Pacific Time (US & Canada)")
      t.strftime("%l:%M%P %Z").strip
    end

    def current_day_low
      day_low(0)
    end

    def current_day_high
      day_high(0)
    end

    def day_label(day_index)
      day(day_index)[:day_label]
    end

    def day_low(day_index)
      day(day_index)[:low]
    end

    def day_high(day_index)
      day(day_index)[:high]
    end

    def available?
      return false unless formatted_data.present? && formatted_data[:current_temp].present? && formatted_data[:cached_at].present? && formatted_data[:days]&.length == 8
      formatted_data[:days].all? { |d| d[:day_label].present? && d[:high].present? && d[:low].present? }
    end

    def retrieved_from_cache?
      formatted_data[:retrieved_from_cache].present?
    end

    private

    def day(day_index)
      days = formatted_data[:days] || []
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

    def download_raw_data(opts)
      begin
        client = open_weather_client(opts[:open_weather_api_key])
        data = client.one_call(lat: opts[:latitude], lon: opts[:longitude])
      rescue OpenWeather::Errors::Fault => e
        Rails.logger.warn("received fault from OpenWeather: #{e}")
        return [{}, false]
      rescue Faraday::ConnectionFailed => e
        Rails.logger.warn("received connection failed error when attempting to connect to OpenWeather: #{e}")
        return [{}, false]
      end
      [data, true]
    end

    def prepare_cacheable_data(raw_data)
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

    def retrieve_unformatted_data(opts)
      key = cache_key(opts)
      data = Rails.cache.read(key)
      if data
        data[:retrieved_from_cache] = true
      else
        raw_data, success = download_raw_data(opts)
        return [{}, false] unless success

        data = prepare_cacheable_data(raw_data)
        Rails.cache.write(key, data, expires_in: WEATHER_CACHE_EXPIRATION)
        data[:retrieved_from_cache] = false
      end
      [data, true]
    end

    def format_temps(data, temp_unit)
      data = data.dup
      data[:current_temp] = format_temp(data[:current_temp], temp_unit)
      data[:days] = data[:days].dup
      data[:days].each_with_index do |d, day_index|
        data[:days][day_index][:low] = format_temp(data[:days][day_index][:low], temp_unit)
        data[:days][day_index][:high] = format_temp(data[:days][day_index][:high], temp_unit)
      end
      data
    end

    def format_temp(temp, temp_unit)
      temp = celsius_to_fahrenheit(temp) unless temp_unit&.to_s == "celsius"
      temp.round
    end

    ZERO_CELSIUS_IN_KELVIN = -273.15
    def kelvin_to_celsius(temp_k)
      (temp_k.to_f + ZERO_CELSIUS_IN_KELVIN).round(2)
    end

    def celsius_to_fahrenheit(temp_c)
      (temp_c.to_f * 9.0 / 5.0 + 32.0).round(2)
    end
  end
end

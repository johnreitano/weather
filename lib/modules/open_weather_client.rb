module OpenWeatherClient
  WEATHER_CACHE_EXPIRATION = 20.seconds
  def self.retrieve_weather(opts)
    cached_data_key = key(opts)
    data = Rails.cache.read(cached_data_key)
    if data
      data[:cached] = true
    else
      data, success = load_and_prepare_cacheable_data(opts)
      return [{}, false] unless success
      Rails.cache.write(cached_data_key, data, expires_in: WEATHER_CACHE_EXPIRATION)
      data[:cached] = false
    end

    data = format_temps(data, opts[:temp_unit])
    [data, true]
  end

  # private_class_method

  def self.key(opts)
    "WEATHER/#{opts[:zip]}/#{opts[:country]}"
  end

  def self.load_raw_data(opts)
    @client ||= OpenWeather::Client.new(api_key: Rails.application.credentials.dig("open_weather_api_key"))
    begin
      data = @client.one_call(lat: opts[:latitude], lon: opts[:longitude])
    rescue OpenWeather::Errors::Fault => e
      Rails.logger.warn("received fault from OpenWeather: #{e}")
      return [{}, false]
    rescue Faraday::ConnectionFailed => e
      Rails.logger.warn("received connection failed error when attempting to connect to OpenWeather: #{e}")
      return [{}, false]
    end
    [data, true]
  end

  def self.load_and_prepare_cacheable_data(opts)
    raw_data, success = load_raw_data(opts)
    return [{}, false] unless success

    data = {
      current_temp: k_to_c(raw_data.dig("current", "temp")),
      days: raw_data["daily"][0..7].each_with_index.map do |d, i|
        {
          day: d["dt"].strftime("%a %d"),
          low: k_to_c(d.dig("temp", "min")),
          high: k_to_c(d.dig("temp", "max"))
        }
      end
    }
    [data, true]
  end

  def self.format_temps(data, temp_unit)
    {
      current_temp: format_temp(data[:current_temp], temp_unit),
      days: data[:days][0..7].each_with_index.map do |d, i|
        {
          day: d[:day],
          low: format_temp(data[:days][i][:low], temp_unit),
          high: format_temp(data[:days][i][:high], temp_unit)
        }
      end,
      cached: data[:cached]
    }
  end

  def self.format_temp(temp, temp_unit)
    temp = c_to_f(temp) if temp_unit&.to_s == "fahrenheit"
    temp.round(1)
  end

  ZERO_CELSIUS_IN_KELVIN = -273.15
  def self.k_to_c(temp_k)
    (temp_k.to_f + ZERO_CELSIUS_IN_KELVIN).round(2)
  end

  def self.c_to_f(temp_c)
    (temp_c.to_f * 9.0 / 5.0 + 32.0).round(2)
  end
end

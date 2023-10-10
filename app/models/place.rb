# Place repreents a place with an address (including a zipcode and country); this model is is used to validate an address and retrieve associated weather data from an external API
class Place
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_accessor :full_address
  attr_reader :weather_data, :open_weather_client
  attribute :latitude, :float
  attribute :longitude, :float
  attribute :city, :string
  attribute :state, :string
  attribute :zipcode, :string
  attribute :country, :string
  attribute :temp_unit, :string

  validates :latitude, numericality: {greater_than_or_equal_to: -90, less_than_or_equal_to: 90}
  validates :longitude, numericality: {greater_than_or_equal_to: -180, less_than_or_equal_to: 180}
  validates :zipcode, zipcode: {country_code_attribute: :country, message: "is invalid for selected country"}, if: -> { zipcode.present? && country.present? }
  validates :zipcode, presence: true, if: -> { country.present? }
  validates :country, inclusion: {in: ISO3166::Country.codes, message: "is invalid"}, if: -> { country.present? }
  validates :country, presence: true
  validates :temp_unit, inclusion: {in: ["fahrenheit", "celsius"], allow_blank: true, message: "must be 'fahrenheit' or 'celsius'"}

  def initialize(params = {})
    @weather_data = {}
    @open_weather_client = OpenWeatherClient
    super(params)
  end

  def retrieve_weather
    return false unless valid?
    opts = attributes.slice("latitude", "longitude", "city", "state", "zipcode", "country", "temp_unit").symbolize_keys
    @weather_data, success = @open_weather_client.retrieve_weather(opts)
    errors.add(:weather_data, "could not be retrieved from weather service") unless success
    success
  end

  def current_temp
    weather_data[:current_temp]
  end

  def cached_at
    t = weather_data[:cached_at]
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

  def day(day_index)
    days = weather_data[:days] || []
    return {} if day_index > days.length - 1
    days[day_index]
  end

  def has_weather_data?
    return false unless weather_data.present? && weather_data[:current_temp].present? && weather_data[:cached_at].present? && weather_data[:days]&.length == 8
    weather_data[:days].all? { |d| d[:day_label].present? && d[:high].present? && d[:low].present? }
  end

  def retrieved_from_cache?
    weather_data[:retrieved_from_cache].present?
  end
end

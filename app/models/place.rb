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
    errors.add(:weather_data, "could not be retrieve from weather service") unless success
    success
  end

  def current_temp
    weather_data[:current_temp]
  end

  def retrieved_at
    weather_data[:retrieved_at]
  end

  def current_day_low
    day_low(0)
  end

  def current_day_high
    day_high(0)
  end

  def day_label(i)
    day(i)[:day_label]
  end

  def day_low(i)
    day(i)[:low]
  end

  def day_high(i)
    day(i)[:high]
  end

  def day(i)
    self.weather_data ||= {}
    days = weather_data[:days] || []
    return {} if i > days.length - 1
    days[i]
  end

  def has_weather_data?
    return false unless weather_data.present? && weather_data[:current_temp].present? && weather_data[:days].present? && weather_data[:days].length == 8

    weather_data[:days].all? { |d| d[:day_label].present? && d[:high].present? && d[:low].present? }
  end

  def cached?
    weather_data[:cached].present?
  end
end

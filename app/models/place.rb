class Place
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_accessor :full_address, :weather_data
  attribute :latitude, :float
  attribute :longitude, :float
  attribute :country, :string
  attribute :country, :string
  attribute :zipcode, :string
  attribute :temp_unit, :string

  validates :latitude, numericality: {greater_than_or_equal_to: -90, less_than_or_equal_to: 90}
  validates :longitude, numericality: {greater_than_or_equal_to: -180, less_than_or_equal_to: 180}
  validates :zipcode, zipcode: {country_code_attribute: :country, message: "is invalid for selected country"}, if: -> { zipcode.present? && country.present? }
  validates :zipcode, presence: true, if: -> { country.present? }
  validates :country, inclusion: {in: ISO3166::Country.codes, message: "is invalid"}, if: -> { country.present? }
  validates :country, presence: true
  validates :temp_unit, inclusion: {in: ["fahrenheit", "celsius"], allow_blank: true, message: "must be 'fahrenheit' or 'celsius'"}

  def retrieve_weather
    return false unless valid?
    opts = attributes.slice("latitude", "longitude", "zipcode", "country", "temp_unit").symbolize_keys
    self.weather_data, success = OpenWeatherClient.retrieve_weather(opts)
    errors.add(:weather_data, "could not be retrieve from weather service") unless success
    success
  end

  def current_temp
    (weather_data || {})[:current_temp]
  end

  def current_time
    now = Time.zone.now.in_time_zone("Pacific Time (US & Canada)")
    now.strftime("%l:%M%p %Z").strip
  end

  def current_day_description
    day_description(0)
  end

  def current_day_low
    day_low(0)
  end

  def current_day_high
    day_high(0)
  end

  def day_description(i)
    day(i)[:day]
  end

  def day_low(i)
    day(i)[:low]
  end

  def day_high(i)
    day(i)[:high]
  end

  def day(i)
    days = (weather_data || {})[:days] || []
    return {} if i > days.length - 1
    days[i]
  end

  def has_weather_data?
    !(weather_data || {}).empty?
  end
end

# frozen_string_literal: true

# Place repreents a place with an address (including a zipcode and country); this model is is used to validate an address and retrieve associated weather data from an external API
class Place
  include ActiveModel::Model
  include ActiveModel::Attributes
  include OpenWeatherDataRetriever

  open_weather_data :weather_data

  attr_accessor :full_address

  attribute :latitude, :float
  attribute :longitude, :float
  attribute :city, :string
  attribute :state, :string
  attribute :zipcode, :string
  attribute :country, :string
  attribute :temp_unit, :string

  validates :latitude, numericality: {greater_than_or_equal_to: -90, less_than_or_equal_to: 90}
  validates :longitude, numericality: {greater_than_or_equal_to: -180, less_than_or_equal_to: 180}
  validates :zipcode, zipcode: {country_code_attribute: :country, message: "is invalid for selected country"}, if: lambda {
                                                                                                                     zipcode.present? && country.present?
                                                                                                                   }
  validates :zipcode, presence: true, if: -> { country.present? }
  validates :country, inclusion: {in: ISO3166::Country.codes, message: "is invalid"}, if: -> { country.present? }
  validates :country, presence: true
  validates :temp_unit,
    inclusion: {in: %w[fahrenheit celsius], allow_blank: true, message: "must be 'fahrenheit' or 'celsius'"}

  def validate_request_and_retrieve_weather_data
    return false unless valid?

    opts = attributes.slice("latitude", "longitude", "city", "state", "zipcode", "country", "temp_unit").symbolize_keys
    api_key = Rails.application.credentials[:open_weather_api_key]
    success = weather_data.retrieve(opts.merge(open_weather_api_key: api_key))
    errors.add(:weather_data, "could not be retrieved from weather service") unless success
    success
  end
end

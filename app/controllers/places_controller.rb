class PlacesController < ApplicationController
  # GET /places or /places.json
  def index
    @place = Place.new
    @temp_unit = "fahrenheight"
    @time_zone = "Pacific Time (US & Canada)"
    @weather_data = @place.weather_data
  end

  # POST /places or /places.json
  def create
    @place = Place.new(place_params)
    @temp_unit = "fahrenheight"
    @time_zone = "Pacific Time (US & Canada)"
    success = @place.validate_request_and_retrieve_weather_data
    @weather_data = @place.weather_data
    render :index, status: success ? :created : :unprocessable_entity
  end

  private

  def place_params
    params.require(:place).permit(:full_address, :latitude, :longitude, :city, :state, :zipcode, :country, :temp_unit)
  end
end

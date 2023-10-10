class PlacesController < ApplicationController
  # GET /places or /places.json
  def index
    @place = Place.new
  end

  # POST /places or /places.json
  def create
    @place = Place.new(place_params)
    success = @place.validate_request_and_retrieve_weather_data
    render :index, status: success ? :created : :unprocessable_entity
  end

  private

  # Only allow a list of trusted parameters through.
  def place_params
    params.require(:place).permit(:full_address, :latitude, :longitude, :city, :state, :zipcode, :country, :temp_unit)
  end
end

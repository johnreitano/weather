class PlacesController < ApplicationController
  # GET /places or /places.json
  def index
    @place = Place.new
  end

  # POST /places or /places.json
  def create
    @place = Place.new(place_params)

    respond_to do |format|
      if @place.retrieve_weather
        format.html { render :index, status: :created }
        format.json { render :show, status: :created, location: @place }
      else
        format.html { render :index, status: :unprocessable_entity }
        format.json { render json: @place.errors, status: :unprocessable_entity }
      end
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_place
    @place = Place.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def place_params
    params.require(:place).permit(:full_address, :latitude, :longitude, :city, :state, :zipcode, :country, :temp_unit)
  end
end

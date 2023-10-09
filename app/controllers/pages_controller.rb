class PagesController < ApplicationController
  def home
  end

  def weather
    values = Weather.retrieve(weather_params)
    Rails.logger.info("values=#{values}")
  end

  private

  def weather_params
    params.require(:person).permit(:lat, :lon, :zipcode, :country, :temp_unit)
  end
end

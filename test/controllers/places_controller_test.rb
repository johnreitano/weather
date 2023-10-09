require "test_helper"

class PlacesControllerTest < ActionDispatch::IntegrationTest
  test "should return home page" do
    get root_url
    assert_response :success
  end

  test "should retrieve data for a specified place" do
    @place = Place.new(latitude: 32.6502944, longitude: -116.983784, city: "Chula Vista", state: "CA", zipcode: "91913", country: "US", temp_unit: "fahrenheit")

    # stub for returning data in successful scenarios
    def OpenWeatherClient.download_raw_data(opts)
      [{"current" => {"temp" => 303.82}, "daily" => [{"dt" => "2023-10-07 19:00:00 UTC".to_datetime, "temp" => {"min" => 294.61, "max" => 303.82}}, {"dt" => "2023-10-08 19:00:00 UTC".to_datetime, "temp" => {"min" => 295.77, "max" => 304.76}}, {"dt" => "2023-10-09 19:00:00 UTC".to_datetime, "temp" => {"min" => 292.9, "max" => 300.5}}, {"dt" => "2023-10-10 19:00:00 UTC".to_datetime, "temp" => {"min" => 290.95, "max" => 296.3}}, {"dt" => "2023-10-11 19:00:00 UTC".to_datetime, "temp" => {"min" => 291.47, "max" => 295.51}}, {"dt" => "2023-10-12 19:00:00 UTC".to_datetime, "temp" => {"min" => 290.68, "max" => 296.23}}, {"dt" => "2023-10-13 19:00:00 UTC".to_datetime, "temp" => {"min" => 291.02, "max" => 296.48}}, {"dt" => "2023-10-14 19:00:00 UTC".to_datetime, "temp" => {"min" => 290.71, "max" => 296.79}}]}, true]
    end

    post root_url, params: {place: {city: @place.city, state: @place.state, country: @place.country, latitude: @place.latitude, longitude: @place.longitude, zipcode: @place.zipcode}}
    assert_response :success
  end
end

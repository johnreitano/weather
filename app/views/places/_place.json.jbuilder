json.extract! place, :id, :latitude, :longitude, :zipcode, :country, :created_at, :updated_at
json.url place_url(place, format: :json)

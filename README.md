# Weather Station

An app that displays current and forecast weather for an address entered by the user.

# Installing and running the app

```
git clone git@github.com:johnreitano/weather.git
cd weather
bundle install
bin/dev
```

Then visit http://localhost:3000

### Live Demo

See https://weather-ex6k.onrender.com

### External Data Sources

There following two external data sources are used:

- The "Place Autocomplete" feature of the Google Maps API provides autocompletion and geocoding of addresses (See https://developers.google.com/maps/documentation/javascript/place-autocomplete).
- The one_call method in OpenWeather's "One Call API" provides this app's core weather data (see https://openweathermap.org/api/one-call-3). This API is accessed via the gem "open-weather-ruby-client" (see https://github.com/dblock/open-weather-ruby-client).

### Internal Design

- The app is built with Rails 7 using Ruby 3.2 and Tailwind CSS.
- The app doesn't use a traditional Rails database, but it does cache weather data in the Rails cache. (See "Scaling" below.)
- Most of the work of the app is done in the following 4 parts of the app:
  - The app's home page makes use of a Javascript "controller" file (`app/javascript/controllers/places_controller.js`), which does the following:
    - manages input from the user
    - connects to Google Maps API
    - obtains an autocompleted, validated and geocoded address
    - passes this address on to the Rails app via a POST to the app's root url
  - The controller `PlacesController` (`app/controllers/place_controller.rb`) does the following:
    - receives address data from the home page
    - passes ths data to an instance of the model Place
    - updates the home page based on the results from the model
  - The model `Place` (`app/models/place.rb`) does the following:
    - receives address data originating the home page.
    - validates the address
    - passes the adddress to the `retrieve` method of the class `WeatherDataRetriever::WeatherData` (see below)
    - returns the boolean indicating success or failure of the `retrieve` method
    - does NOT represent a subclass of `ActiveRecord::Base`. Instead, it includes the Rails modules `ActiveModel::Model` and `ActiveModel::Attributes` to do validation.
  - The concern `WeatherDataRetriever` (`app/models/conncerns/weather_data_retriever.rb`) does most of the work of this app. The method `retrieve` in the class `WeatherDataRetriever::WeatherData` does the following:
    - receives the geocoded address
    - retrieves the associated weather data for the current day and a 7-day forecast.
    - Uses the cached value of data for a particular zipcode if available. This cached data is available for 30 minutes.

### Scaling

- Scaling the core app itself can be done by using a load balancer to run multiple instances of the app in parallel.
- Currently, the cache used by the app is stored in the file system. This apporach will not handle many users. To run this app in production at any kind of reasonable scale, a robut cacheing database (such as Redis) should be used. Switching to a database such as Redis will require setting up the database and then making some minor configurating changes to the app.
- The external data services will need to be investigated for handling any kind of scale:
  - Google Maps API can handle quite a lot of scale, but costs need to be investigated.
  - The OpenWeather API may need to be investigateed both for ability to handle scale and for costs.

### Running tests

```
rails test # unit and integration tests
rails test test/system # system tests
```

### Deloyment

Currently automatically deployed to render.com when commit added to main branch of this repo.

### Possible improvements

- Cacheing is currently done via the file system, but should be moved to Redis in production
- Allow front-end to switch between Fahrenheit and Celsius (and default to typical unit for user's location)
- Show times in end-user's time zone instead of in Pacific Time.
- I've done some testing in Chrome, Firefox and Safari on Mac, and Chrome and Safari on IOS, but further testing is needed.

# Weather

An app that retrieves current and forecast weather based on an address entered by a user.

### Live Demo

See https://weather-ex6k.onrender.com

### External Data Sources

There following two external data sources are used:

- The "Place Autocomplete" feature of the Google Maps API provides autocompletion and geocoding of addresses (See https://developers.google.com/maps/documentation/javascript/place-autocomplete).
- The one_call method Open Call API from OpenWeather provides the core weather data (see https://openweathermap.org/api/one-call-3). This API is accessed via the gem "open-weather-ruby-client" (see https://github.com/dblock/open-weather-ruby-client).

### Internal Design

- The app is built with Rails 7 using Ruby 3.2 and Tailwind.
- The app doesn't use a traditional Rails database, but it does cache weather data in the Rails cache. (See "Scaling" below.)
- Most of the work of the app is done in the following 4 parts of the app:
  - The app's home page makes use of a Javascript "controller" file (`app/javascript/controllers/places_controller.js`), which does the following:
    - manages input from the user
    - connects to Google Maps API
    - obtains an autocompleted, validated and geocoded address
    - passes this address on to the Rails app via a POST to the app's root url
  - The controller PlacesController (`app/controllers/place_controller.rb`) does the following:
    - receives address data from the home page
    - passes ths data to an instance of the model Place
    - updates the home page based on the results from the model
  - The model Place (`app/models/place.rb`) does the following:
    - receives address data originating the home page. Instead a save method, this model uses the method `retrieve_weather`.
    - passes this data to the module OpenWeatherClient
    - stores the resulting data in memory
    - returns a boolean indicating success or failure.
    - does NOT represent a subclass of ActiveRecord::Base. Instead, it includes Rails' `ActiveModel` to make use of the Rails validation features.
  - The module OpenWeatherClient (`lib/modules/open_weather_client.rb`) does the following:
    - receives the geocoded address
    - retrieves the associated weather data for the current day and a 7-day forecast, returning this data in nested Ruby Hash.
    - Uses cached for a particular zipcode if available. This cached data is available for 30 minutes.

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
- Allow front-end to switch between Fahrenheit and Celsius
- Show times in end-user's time zone instead of in Pacific Time.
- I've done some testing in Chrome, Firefox and Safari on Mac, and Chrome and Safari on IOS, but further testing is needed.

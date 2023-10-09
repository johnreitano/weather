# Weather

An app that retrieves current and forecast weather based on entered address

### Running tests

```
rails test # unit and integration tests
rails test test/system # system tests
```

### Deloyment

### Other details

- Ruby verson: 3.2.2
- Rails verson: 7.1.0
- Uses OpenWeather API via gem open-weather-ruby-client

### Future improvements

- Cacheing is currently done via file system, but should be moved to Redis in production
- Allow front-end to switch between Fahrenheit and Celsius

### TODO

- Organize Front End
- Style Front End
- complete system tests

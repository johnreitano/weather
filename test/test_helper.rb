# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require "simplecov"
SimpleCov.start
require_relative "../config/environment"
require "rails/test_help"
require "minitest/autorun"
require "minitest/around/unit"
require "minitest/spec"

def stub_successful_open_weather_response(&block)
  body = {
    "current" => {"temp" => 303.82},
    "daily" => [
      {"dt" => "2023-09-02 19:00:00 UTC".to_time.to_i, "temp" => {"min" => 294.61, "max" => 304.82}},
      {"dt" => "2023-09-03 19:00:00 UTC".to_time.to_i, "temp" => {"min" => 295.77, "max" => 304.76}},
      {"dt" => "2023-09-04 19:00:00 UTC".to_time.to_i, "temp" => {"min" => 292.9, "max" => 300.5}},
      {"dt" => "2023-09-05 19:00:00 UTC".to_time.to_i, "temp" => {"min" => 290.95, "max" => 296.3}},
      {"dt" => "2023-09-06 19:00:00 UTC".to_time.to_i, "temp" => {"min" => 291.47, "max" => 295.51}},
      {"dt" => "2023-09-07 19:00:00 UTC".to_time.to_i, "temp" => {"min" => 290.68, "max" => 296.23}},
      {"dt" => "2023-09-08 19:00:00 UTC".to_time.to_i, "temp" => {"min" => 291.02, "max" => 296.48}},
      {"dt" => "2023-09-09 19:00:00 UTC".to_time.to_i, "temp" => {"min" => 290.71, "max" => 296.79}}
    ]
  }

  mock_response = Struct.new(:code, :body).new(code: 200, body: body.to_json)
  RestClient.stub :get, mock_response, &block
end

def stub_failed_open_weather_response(code, &block)
  body = {message: "an error occurred"}
  mock_response = Struct.new(:code, :body).new(code: code, body: body.to_json)
  RestClient.stub :get, mock_response, &block
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

# frozen_string_literal: true

require "application_system_test_case"

class PlacesTest < ApplicationSystemTestCase
  setup do
    Rails.cache.clear
  end

  def retrieve_weather_info(entered_address)
    visit root_url
    assert_selector "h1", text: "Weather Station"
    full_address = find_by_id("full_address", wait: 5)
    10.times do
      break if full_address[:placeholder].present?
      # :nocov:

      Rails.logger.debug "waiting for google maps to initialize address field..."
      sleep 0.5
      # :nocov:
    end
    fill_in "full_address", with: entered_address
    els = page.all(:css, ".pac-item", wait: 5)
    return false if els.blank?

    full_address.send_keys :arrow_down
    assert has_selector?(".pac-item-selected", wait: 10)

    full_address.send_keys :enter

    return false unless has_selector?("#weather_data_present", wait: 5)

    today = page.find(:css, "#today", wait: 5)
    current_temp = today.find(:css, ".today_current_temp", wait: 5)
    current_temp.assert_text(/Current Temp +\d+/)
    today_high_low = today.find(:css, ".today_high_low", wait: 5)
    today_high_low.assert_text(%r{Today's High/Low +\d+})

    forecast = page.find(:css, "#forecast", wait: 5)

    (1..7).each do |day_index|
      day = forecast.find(:css, "#day-#{day_index}", wait: 5)
      day_label = day.find(:css, ".day_label", wait: 5)
      day_label.assert_text(/(Mon|Tue|Wed|Thu|Fri|Sat|Sun) +\d{1,2}/)
      day_high_low = day.find(:css, ".day_high_low", wait: 5)
      day_high_low.assert_text(/\d+/)
    end
    true
  end

  test "retrieving weather info (happy path)" do
    # retrieve live/non-cached data for particular address
    assert retrieve_weather_info("2205 South Melrose Drive, Vista, CA")
    el = page.find(:css, "#weather_data_present")
    el.assert_no_text("(Cached)")

    # retrieving same address should retrieve cached data
    assert retrieve_weather_info("2205 South Melrose Drive, Vista, CA")
    el = page.find(:css, "#weather_data_present")

    el.assert_text("(Cached)")
  end

  test "retrieving weather info (sad path: nonexistent address, user likely still typing)" do
    refute retrieve_weather_info("123 Nonexistent")
    assert has_no_selector?("#address_error")
    assert has_no_selector?("#weather_data_pending")
    assert has_no_selector?("#weather_data_error")
  end

  test "retrieving weather info (sad path: selected address missing zip code)" do
    refute retrieve_weather_info("Antarctica")
    assert has_selector?("#address_error")
    assert has_no_selector?("#weather_data_pending")
    assert has_no_selector?("#weather_data_error")
  end
end

require "application_system_test_case"

class PlacesTest < ApplicationSystemTestCase
  def retrieve_weather_info(entered_address)
    visit root_url
    assert_selector "h1", text: "Weather Station"
    full_address = find_by_id("full_address", wait: 5)
    5.times do
      break if full_address[:placeholder].present?
      puts "waiting for google maps to initialize address field..."
      sleep 1
    end
    fill_in "full_address", with: entered_address
    els = page.all(:css, ".pac-item", wait: 5)
    return false if els.blank?
    full_address.send_keys :arrow_down
    assert has_select?(".pac-item-selected", wait: 5)
    full_address.send_keys :enter
    el = page.find(:css, "#weather_title", wait: 5)
    assert el.text =~ /2295 Otay Lakes Rd, Chula Vista, CA, USA at \d{1,2}:\d\d(am|pm) \w+T/

    today = page.find(:css, "#today", wait: 5)
    current_temp = today.find(:css, ".current_temp", wait: 5)
    current_temp.assert_text(/Current Temp +\d+.\d/)
    day_high = today.find(:css, ".day_high", wait: 5)
    day_high.assert_text(/Today's High +\d+.\d/)
    day_low = today.find(:css, ".day_low", wait: 5)
    day_low.assert_text(/Today's Low +\d+.\d/)

    forecast = page.find(:css, "#forecast", wait: 5)
    section_title = forecast.find(:css, ".section_title", wait: 5)
    section_title.assert_text(/7-day Forecast/)

    (1..7).each do |i|
      day = forecast.find(:css, "#day-#{i}", wait: 5)
      day_label = day.find(:css, ".day_label", wait: 5)
      day_label.assert_text(/(Mon|Tue|Wed|Thu|Fri|Sat|Sun) +\d{1,2}/)
      day_high = day.find(:css, ".day_high", wait: 5)
      day_high.assert_text(/High +\d+.\d/)
      day_low = day.find(:css, ".day_low", wait: 5)
      day_low.assert_text(/Low +\d+.\d/)
    end

    true
  end

  test "retrieving weather info (happy path)" do
    # retrieve live/non-cached data for particular address
    Rails.cache.clear
    assert retrieve_weather_info("2205 South")
    el = page.find(:css, "#weather_title", wait: 5)
    el.assert_no_text("(Cached)")

    # retrieve cached data same address
    assert retrieve_weather_info("2205 South")
    el = page.find(:css, "#weather_title", wait: 5)
    el.assert_text("(Cached)")
  end

  test "retrieving weather info (sad path: invalid address)" do
    Rails.cache.clear
    refute retrieve_weather_info("123 Nonexistent Street")
    assert has_no_select?("#weather_title")
  end

  test "retrieving weather info (sad path: missing zip code)" do
    Rails.cache.clear
    refute retrieve_weather_info("Antarctica")
    assert has_no_select?("#weather_title")
    assert has_select?("#weather_data_error")
  end
end

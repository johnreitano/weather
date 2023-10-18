import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'weather_form',
    'full_address',
    'city',
    'state',
    'zipcode',
    'country',
    'latitude',
    'longitude',
    'address_error',
    'weather_data_present',
    'weather_data_pending',
    'weather_data_error',
  ]

  connect() {
    console.log('places controller: connected')
    if (typeof google != 'undefined') {
      this.initGoogle()
    }
  }

  initGoogle() {
    console.log('places controller: initializing Google Maps client')
    this.autocomplete = new google.maps.places.Autocomplete(
      this.full_addressTarget,
      {
        fields: ['address_components', 'geometry'],
        // types: ['address'],
      }
    )
    this.autocomplete.addListener(
      'place_changed',
      this.placeSelected.bind(this)
    )

    const form = document.getElementById('weather_form')
    let fullAddress = this.full_addressTarget
    form.addEventListener('keydown', function (e) {
      if (e.code == 'Enter') {
        console.log('preventing early submit')
        e.preventDefault() // postpone submitting form until user has selected a geocoded place from list

        if (e.triggered) {
          return // skip simulation below if it has already run
        }

        // simulating pressing of down-arrow and enter keys
        console.log('simulating pressing of down-arrow and enter keys')
        var ex1 = new Event('keydown')
        ex1.code = 'ArrowDown'
        ex1.key = 'ArrowDown'
        ex1.keyCode = 40
        fullAddress.dispatchEvent(ex1)
        var ex2 = new Event('keydown')
        ex2.code = 'Enter'
        ex2.key = 'Enter'
        ex2.keyCode = 13
        ex2.triggered = true
        fullAddress.dispatchEvent(ex2)
      }
    })

    fullAddress.disabled = false
    fullAddress.focus()
  }

  placeSelected() {
    console.log('places controller: place selected')
    this.showWeatherDataPending()

    if (!this.extractAddressInfo()) {
      this.showAddressError()
      return
    }

    console.log('programatically submitting')
    this.weather_formTarget.requestSubmit()
  }

  extractAddressInfo() {
    this.latitudeTarget.value = ''
    this.longitudeTarget.value = ''
    this.zipcodeTarget.value = ''
    this.countryTarget.value = ''

    const place = this.autocomplete.getPlace()

    this.latitudeTarget.value = place?.geometry?.location?.lat()
    this.longitudeTarget.value = place?.geometry?.location?.lng()
    if (!this.latitudeTarget.value || !this.longitudeTarget.value) {
      console.log(
        `warning: could not retrieve latitude/longitude info for address ${this.full_addressTarget.value}`
      )
      return false
    }

    for (const component of place?.address_components || []) {
      switch (component.types[0]) {
        case 'locality':
          this.cityTarget.value = component.long_name
          break

        case 'administrative_area_level_1': {
          this.stateTarget.value = component.short_name
          break
        }

        case 'postal_code': {
          this.zipcodeTarget.value = component.long_name
          break
        }

        case 'country':
          this.countryTarget.value = component.short_name
          break
      }
    }
    if (!this.zipcodeTarget.value || !this.countryTarget.value) {
      console.log(
        `warning: could not retrieve zip code + country for address ${this.full_addressTarget.value}`
      )
      return false
    }

    return true
  }

  showAddressError() {
    this.weather_data_presentTarget.hidden = true
    this.weather_data_errorTarget.hidden = true
    this.weather_data_pendingTarget.hidden = true
    this.address_errorTarget.hidden = false
  }

  showWeatherDataPending() {
    this.weather_data_presentTarget.hidden = true
    this.weather_data_errorTarget.hidden = true
    this.weather_data_pendingTarget.hidden = false
    this.address_errorTarget.hidden = true
  }
}

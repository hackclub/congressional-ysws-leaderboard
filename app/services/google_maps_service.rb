require 'singleton'

class GoogleMapsService
  include Singleton

  BASE_URL = 'https://maps.googleapis.com/maps/api/geocode/json'

  def initialize
    @api_key = Rails.application.credentials.google.geocoder_api_key
    @http = HTTPX.with(
      headers: { 'Content-Type' => 'application/json' }
    )
  end

  def geocode(address)
    response = @http.get(BASE_URL, params: {
      address: address,
      key: @api_key
    })

    if response.status == 200
      data = response.json
      if data['status'] == 'OK' && data['results'].any?
        result = data['results'].first
        location = result['geometry']['location']
        
        {
          lat: location['lat'],
          lng: location['lng'],
          formatted_address: result['formatted_address']
        }
      else
        raise "Geocoding Error: #{data['status']} - No results found for address: #{address}"
      end
    else
      raise "Google Maps API Error: #{response.status} - #{response.body.to_s}"
    end
  end
end 
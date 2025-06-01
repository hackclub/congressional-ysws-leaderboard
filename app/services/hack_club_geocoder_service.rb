require "singleton"

class HackClubGeocoderService
  include Singleton

  BASE_URL = "https://geocoder.hackclub.com/v1/geocode"

  def initialize
    @api_key = Rails.application.credentials.hackclub_geocoder_api_key
    @http = HTTPX.with(
      headers: { "Content-Type" => "application/json" }
    )
  end

  def geocode(address)
    response = @http.get(BASE_URL, params: {
      address: address,
      key: @api_key
    })

    if response.status == 200
      data = response.json
      if data["lat"] && data["lng"]
        {
          lat: data["lat"],
          lng: data["lng"],
          formatted_address: data["formatted_address"]
        }
      else
        raise "Geocoding Error: No results found for address: #{address}"
      end
    else
      error_data = response.json rescue {}
      error_message = error_data.dig("error", "message") || response.body.to_s
      raise "Hack Club Geocoder API Error: #{response.status} - #{error_message}"
    end
  end
end

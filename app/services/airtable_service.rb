require 'singleton'
require 'httpx'

class AirtableService
  include Singleton

  BASE_URL = 'https://api.airtable.com/v0'

  def initialize
    @api_key = Rails.application.credentials.airtable.api_key
    @http = HTTPX.with(
      headers: {
        'Authorization' => "Bearer #{@api_key}",
        'Content-Type' => 'application/json'
      }
    )
  end

  def list_records(table_id, offset: nil)
    url = "#{BASE_URL}/#{table_id}"
    params = offset ? { offset: offset } : {}
    
    response = @http.get(url, params: params)
    
    if response.status.success?
      response.json
    else
      raise "Airtable API Error: #{response.status} - #{response.body.to_s}"
    end
  end
end 
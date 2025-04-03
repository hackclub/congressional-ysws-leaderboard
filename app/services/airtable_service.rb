require 'singleton'
require 'httpx'
require 'uri'

class AirtableService
  include Singleton

  BASE_URL = 'https://api.airtable.com/v0'

  def initialize
    @api_key = Rails.application.credentials.airtable.pat
    @base_id = Rails.application.credentials.airtable.ysws.base_id
    @http = HTTPX.with(
      headers: {
        'Authorization' => "Bearer #{@api_key}",
        'Content-Type' => 'application/json'
      }
    )
  end

  def list_records(table_id, offset: nil)
    url = URI.join(BASE_URL + '/', @base_id + '/', table_id).to_s
    params = { offset: offset }.compact

    response = @http.get(url, params: params)
    
    if response.status == 200
      JSON.parse(response.body)
    else
      raise "Airtable API Error: #{response.status} - #{response.body.to_s}"
    end
  end
end 
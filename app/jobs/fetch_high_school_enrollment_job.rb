require 'net/http'
require 'json'
require 'uri'

class FetchHighSchoolEnrollmentJob < ApplicationJob
  queue_as :default

  # ACS 5-Year Estimates Year (Update as needed)
  ACS_YEAR = 2022 
  # Variable for High School Enrollment (Grade 9-12)
  # From table B14007: School Enrollment by Level of School
  ENROLLMENT_VAR = 'B14007_007E' 

  # Basic mapping - expand as needed or use a gem
  STATE_FIPS = {
    'AL' => '01', 'AK' => '02', 'AZ' => '04', 'AR' => '05', 'CA' => '06',
    'CO' => '08', 'CT' => '09', 'DE' => '10', 'FL' => '12', 'GA' => '13',
    'HI' => '15', 'ID' => '16', 'IL' => '17', 'IN' => '18', 'IA' => '19',
    'KS' => '20', 'KY' => '21', 'LA' => '22', 'ME' => '23', 'MD' => '24',
    'MA' => '25', 'MI' => '26', 'MN' => '27', 'MS' => '28', 'MO' => '29',
    'MT' => '30', 'NE' => '31', 'NV' => '32', 'NH' => '33', 'NJ' => '34',
    'NM' => '35', 'NY' => '36', 'NC' => '37', 'ND' => '38', 'OH' => '39',
    'OK' => '40', 'OR' => '41', 'PA' => '42', 'RI' => '44', 'SC' => '45',
    'SD' => '46', 'TN' => '47', 'TX' => '48', 'UT' => '49', 'VT' => '50',
    'VA' => '51', 'WA' => '53', 'WV' => '54', 'WI' => '55', 'WY' => '56',
    'DC' => '11', # District of Columbia
    'PR' => '72'  # Puerto Rico
  }.freeze

  def perform(*args)
    CongressionalDistrict.find_each do |district|
      enrollment_data = fetch_enrollment_for_district(district)

      if enrollment_data
        district.update(high_school_enrollment: enrollment_data)
        Rails.logger.info "Updated enrollment for #{district.name}: #{enrollment_data}"
      else
        Rails.logger.warn "Could not fetch enrollment data for #{district.name}"
      end
      
      # Avoid hitting API rate limits
      sleep(0.2) 
    end
  end

  private

  def fetch_enrollment_for_district(district)
    state_fips = STATE_FIPS[district.state]
    unless state_fips
      Rails.logger.error "No FIPS code found for state: #{district.state}"
      return nil
    end

    # District number needs to be formatted (e.g., 01, 02, ... 10, 11)
    # Assuming district_number is an integer.
    # For state-wide districts (e.g., AK-0, WY-0), Census uses district '00'.
    # Assuming your district_number for these is 0 or 1, adjust as needed.
    # If district_number 0 represents the state-wide district:
    district_code = district.district_number == 0 ? '00' : format('%02d', district.district_number)

    # Construct the API URL
    # Add '&key=YOUR_API_KEY' if you have one
    uri = URI("https://api.census.gov/data/#{ACS_YEAR}/acs/acs5")
    params = {
      get: "NAME,#{ENROLLMENT_VAR}",
      for: "congressional district:#{district_code}",
      in: "state:#{state_fips}"
      # key: ENV['CENSUS_API_KEY'] # Optional: Use an API key from environment variable
    }
    uri.query = URI.encode_www_form(params)

    Rails.logger.info "Fetching Census data from: #{uri}"

    begin
      response = Net::HTTP.get_response(uri)

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error "Census API request failed for #{district.name}: #{response.code} #{response.message}"
        Rails.logger.error "Response body: #{response.body}"
        return nil
      end

      data = JSON.parse(response.body)

      # Expected response format: [["NAME", "B14007_007E", "state", "congressional district"], ["Congressional District X (118th Congress), State", "enrollment_value", "fips", "district_code"]]
      if data.is_a?(Array) && data.length == 2 && data[1].is_a?(Array)
        enrollment_string = data[1][1] # Second element of the second row
        # Check if the value is a non-negative integer string
        if enrollment_string =~ /^\d+$/
          return enrollment_string.to_i
        else
          Rails.logger.warn "Unexpected enrollment value format for #{district.name}: '#{enrollment_string}'"
          return nil # Or handle as 0?
        end
      else
        Rails.logger.warn "Unexpected JSON structure received for #{district.name}: #{data.inspect}"
        return nil
      end

    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse JSON response for #{district.name}: #{e.message}"
      return nil
    rescue StandardError => e
      Rails.logger.error "Error fetching enrollment for #{district.name}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      return nil
    end
  end
end

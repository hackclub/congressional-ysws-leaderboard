require 'net/http'
require 'json'
require 'uri'

# Renamed Job Class
class FetchDistrictDemographicsJob < ApplicationJob 
  queue_as :default

  # ACS 5-Year Estimates Year (Update as needed)
  ACS_YEAR = 2023 
  
  # Variables from ACS Data Profiles (DP) & Detailed Tables (B)
  # DP03_0062E: Median household income in the past 12 months (in YYYY inflation-adjusted dollars)
  # B14007_013E: School Enrollment - Enrolled in grade 9
  # B14007_014E: School Enrollment - Enrolled in grade 10
  # B14007_015E: School Enrollment - Enrolled in grade 11
  # B14007_016E: School Enrollment - Enrolled in grade 12
  INCOME_VAR = 'DP03_0062E' 
  ENROLLMENT_VARS = ['B14007_013E', 'B14007_014E', 'B14007_015E', 'B14007_016E'].freeze

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
    'PR' => '72'  # Puerto Rico - Note: DP variables might differ for PR
  }.freeze

  def perform(*args)
    CongressionalDistrict.find_each do |district|
      demographics = fetch_demographics_for_district(district)

      if demographics
        update_hash = {}
        update_hash[:high_school_enrollment] = demographics[:enrollment] if demographics[:enrollment]
        update_hash[:median_household_income] = demographics[:income] if demographics[:income]

        if update_hash.any?
          district.update(update_hash)
          Rails.logger.info "Updated demographics for #{district.name}: #{update_hash.inspect}"
        else
           Rails.logger.warn "No demographic data found/updated for #{district.name}"
        end
      else
        Rails.logger.warn "Could not fetch demographic data for #{district.name}"
      end
      
      # Avoid hitting API rate limits aggressively
      sleep(0.3) 
    end
  end

  private

  # Fetches enrollment and income via separate API calls
  def fetch_demographics_for_district(district)
    state_fips = STATE_FIPS[district.state]
    unless state_fips
      Rails.logger.error "No FIPS code found for state: #{district.state}"
      return nil
    end

    district_code = district.district_number == 0 ? '00' : format('%02d', district.district_number)

    # Call 1: Fetch Income from /profile endpoint
    income = nil
    profile_endpoint = "https://api.census.gov/data/#{ACS_YEAR}/acs/acs5/profile"
    profile_params = {
      get: "NAME,#{INCOME_VAR}",
      for: "congressional district:#{district_code}",
      in: "state:#{state_fips}"
      # key: ENV['CENSUS_API_KEY'] 
    }
    profile_data = make_census_api_call(profile_endpoint, profile_params, district.name)
    if profile_data
      profile_header = profile_data[0]
      profile_values = profile_data[1]
      income_index = profile_header.index(INCOME_VAR)
      income = parse_value(profile_values[income_index], district.name, "income") if income_index
    end

    # Call 2: Fetch Enrollment from /acs5 endpoint
    enrollment = nil
    acs5_endpoint = "https://api.census.gov/data/#{ACS_YEAR}/acs/acs5"
    acs5_params = {
      get: "NAME,#{ENROLLMENT_VARS.join(',')}", # Request all grade vars
      for: "congressional district:#{district_code}",
      in: "state:#{state_fips}"
      # key: ENV['CENSUS_API_KEY'] 
    }
    acs5_data = make_census_api_call(acs5_endpoint, acs5_params, district.name)
    if acs5_data
      acs5_header = acs5_data[0]
      acs5_values = acs5_data[1]
      # Find indices, parse each value, and sum them up
      total_enrollment = 0
      ENROLLMENT_VARS.each do |var|
        index = acs5_header.index(var)
        if index
          # Parse value, treat nil as 0 for summation
          grade_enrollment = parse_value(acs5_values[index], district.name, "enrollment (#{var})") || 0
          total_enrollment += grade_enrollment
        else
          Rails.logger.warn "Enrollment variable #{var} not found in response header for #{district.name}"
        end
      end
      enrollment = total_enrollment
    end

    # Return nil only if BOTH calls failed entirely (though make_census_api_call handles logging)
    return nil if profile_data.nil? && acs5_data.nil?

    { income: income, enrollment: enrollment }
  end

  def make_census_api_call(endpoint_url, params, district_name)
    uri = URI(endpoint_url)
    uri.query = URI.encode_www_form(params)
    Rails.logger.info "Fetching Census data for #{district_name} from: #{uri}"

    begin
      response = Net::HTTP.get_response(uri)

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error "Census API request failed for #{district_name}: #{response.code} #{response.message}. URL: #{uri}"
        Rails.logger.error "Response body: #{response.body}"
        return nil
      end
      
      # Handle empty or invalid responses
      return nil if response.body.nil? || response.body.empty? || response.body.strip == '[]'


      parsed_data = JSON.parse(response.body)

      # Check for valid structure (header row + data row)
      unless parsed_data.is_a?(Array) && parsed_data.length >= 2 && parsed_data[0].is_a?(Array) && parsed_data[1].is_a?(Array)
        Rails.logger.warn "Unexpected JSON structure received for #{district_name} from #{uri}: #{parsed_data.inspect}"
        return nil
      end
      
      return parsed_data

    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse JSON response for #{district_name} from #{uri}: #{e.message}. Body: #{response&.body}"
      return nil
    rescue StandardError => e
      Rails.logger.error "Error during Census API call for #{district_name} to #{uri}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      return nil
    end
  end

  def parse_value(value_string, district_name, value_type)
      # Census API sometimes returns negative values for income/enrollment when data is unavailable/suppressed. 
      # Treat these cases (and non-numeric strings) as nil.
    if value_string =~ /^-?\d+$/ && value_string.to_i >= 0
       value_string.to_i
    else
      Rails.logger.warn "Invalid or unavailable #{value_type} value ('#{value_string}') received for #{district_name}, treating as nil."
      nil 
    end
  end

end

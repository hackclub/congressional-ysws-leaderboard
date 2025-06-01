require "test_helper"

module Ysws
  class GeocodeProjectJobTest < ActiveJob::TestCase
    test "should update project with existing address" do
      # Create a congressional district
      district = CongressionalDistrict.create!(
        state: "TX",
        district_number: 10,
        boundary: "POLYGON((-96 32, -96 33, -95 33, -95 32, -96 32))"
      )
      
      # Create an existing address with known location
      existing_address = Address.create!(
        address: "123 Test Street, Austin, TX",
        location: "POINT(-95.5 32.5)",
        congressional_district_id: district.id
      )
      
      # Create a test project without location
      project = Ysws::Project.create!(
        airtable_id: "test_project_123",
        fields: {
          "Approved At" => "2025-01-15",
          "YSWS–Weighted Project Contribution" => "5.0"
        }
      )
      
      # Perform the job with the existing address
      GeocodeProjectJob.perform_now("test_project_123", "123 Test Street, Austin, TX")
      
      # Verify the project was updated with the existing address info
      project.reload
      assert_equal existing_address.location, project.location
      assert_equal district.id, project.congressional_district_id
    end
    
    test "should create new address when project address is not found" do
      skip "Integration test - requires valid API key and network"
      
      # Create a test project
      project = Ysws::Project.create!(
        airtable_id: "test_project_new",
        fields: {
          "Approved At" => "2025-01-15",
          "YSWS–Weighted Project Contribution" => "3.0"
        }
      )
      
      test_address = "1600 Amphitheatre Parkway, Mountain View, CA"
      
      # Perform the job - will call real geocoding service
      GeocodeProjectJob.perform_now("test_project_new", test_address)
      
      # Verify a new address was created
      address = Address.find_by(address: test_address)
      assert address.present?
      assert address.location.present?
      
      # Verify the project was updated
      project.reload
      assert_equal address.location, project.location
    end
    
    test "should handle empty address gracefully" do
      # Create a test project
      project = Ysws::Project.create!(
        airtable_id: "test_project_empty",
        fields: {
          "Approved At" => "2025-01-15",
          "YSWS–Weighted Project Contribution" => "2.0"
        }
      )
      
      # Perform the job with empty address
      assert_nothing_raised do
        GeocodeProjectJob.perform_now("test_project_empty", "")
      end
      
      # Verify the project location remains nil
      project.reload
      assert_nil project.location
      assert_nil project.congressional_district_id
    end
    
    test "job uses new HackClubGeocoderService" do
      # Check that HackClubGeocoderService class exists and has the expected methods
      assert defined?(HackClubGeocoderService)
      assert HackClubGeocoderService.instance.respond_to?(:geocode)
      
      # Verify the service uses the Hack Club API endpoint
      assert_equal "https://geocoder.hackclub.com/v1/geocode", HackClubGeocoderService::BASE_URL
    end
  end
end

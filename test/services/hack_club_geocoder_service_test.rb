require "test_helper"

class HackClubGeocoderServiceTest < ActiveSupport::TestCase
  test "geocode should return lat/lng for valid address" do
    skip "Integration test - requires valid API key and internet connection"
    
    service = HackClubGeocoderService.instance
    result = service.geocode("1600 Amphitheatre Parkway, Mountain View, CA")
    
    assert result[:lat].present?
    assert result[:lng].present?
    assert result[:formatted_address].present?
    assert_in_delta 37.4223, result[:lat], 0.1
    assert_in_delta(-122.0844, result[:lng], 0.1
    )
  end

  test "geocode should raise error for invalid address" do
    skip "Integration test - requires valid API key and internet connection"
    
    service = HackClubGeocoderService.instance
    
    assert_raises(StandardError) do
      service.geocode("invalid address that does not exist")
    end
  end
end

class Address < ApplicationRecord
  class GeocodeError < StandardError
    attr_reader :original_error, :address, :status, :invalid_input

    def initialize(msg = nil, original_error: nil, address: nil, status: nil, invalid_input: false)
      @original_error = original_error
      @address = address
      @status = status
      @invalid_input = invalid_input
      super(msg || original_error&.message)
    end
  end

  validates :address, presence: true, uniqueness: true
  validates :location, presence: true, unless: :invalid_address?

  before_validation :geocode_address, on: :create

  def self.geocode!(address)
    # Try to find by exact user input
    found = find_by(address: address)
    return found if found

    # If not found, geocode and create new record
    begin
      result = GoogleMapsService.instance.geocode(address)
      
      create!(
        address: address,  # Keep original user input
        location: "POINT(#{result[:lng]} #{result[:lat]})"
      )
    rescue => e
      if invalid_input_error?(e)
        # For invalid input, create record with nil location
        create!(
          address: address,
          location: nil,
          invalid_address: true
        )
      else
        # For other errors (API issues, network problems, etc), raise error
        raise GeocodeError.new(
          "Failed to geocode address: #{address}",
          original_error: e,
          address: address,
          status: e.try(:status),
          invalid_input: invalid_input_error?(e)
        )
      end
    end
  end

  private

  def self.invalid_input_error?(error)
    error.message.include?("INVALID_REQUEST") || 
      error.message.include?("ZERO_RESULTS") ||
      error.message.include?("Missing the 'address'")
  end

  def invalid_address?
    invalid_address == true
  end

  def geocode_address
    return if address.blank?
    return if invalid_address? # Skip geocoding if already marked invalid

    begin
      result = GoogleMapsService.instance.geocode(address)
      self.location = "POINT(#{result[:lng]} #{result[:lat]})"
      self.invalid_address = false
    rescue => e
      if self.class.invalid_input_error?(e)
        self.location = nil
        self.invalid_address = true
      else
        errors.add(:address, :geocoding_failed, 
          message: "Could not geocode address: #{e.message}",
          status: e.try(:status)
        )
      end
    end
  end
end

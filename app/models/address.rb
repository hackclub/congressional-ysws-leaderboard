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

  belongs_to :congressional_district, optional: true

  validates :address, presence: true, uniqueness: true
  validates :location, presence: true, unless: -> { invalid_address? || congressional_district_id.present? }

  before_validation :geocode_and_find_district, on: :create

  def self.find_or_geocode_and_set_district!(address_text)
    found = find_by(address: address_text)
    return found if found

    new_address = new(address: address_text)
    new_address.geocode_and_find_district
    new_address.save!
    new_address
  rescue => e
    if invalid_input_error?(e)
      existing_invalid = find_by(address: address_text, invalid_address: true)
      return existing_invalid if existing_invalid
      create!(address: address_text, location: nil, invalid_address: true, congressional_district_id: nil)
    else
      raise GeocodeError.new(
        "Failed to geocode or save address: #{address_text}",
        original_error: e,
        address: address_text,
        status: e.try(:status),
        invalid_input: invalid_input_error?(e)
      )
    end
  end

  def geocode_and_find_district
    return if address.blank?
    return if location.present? || invalid_address?

    begin
      result = GoogleMapsService.instance.geocode(address)
      new_location = "POINT(#{result[:lng]} #{result[:lat]})"
      self.location = new_location
      self.invalid_address = false

      district = CongressionalDistrict.find_by_location(new_location)
      self.congressional_district_id = district&.id

    rescue => e
      if self.class.invalid_input_error?(e)
        self.location = nil
        self.invalid_address = true
        self.congressional_district_id = nil
      else
        errors.add(:address, :geocoding_failed,
                   message: "Could not geocode address: #{e.message}",
                   status: e.try(:status))
        self.congressional_district_id = nil
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
end

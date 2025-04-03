class Address < ApplicationRecord
  validates :address, presence: true, uniqueness: true
  validates :location, presence: true

  before_validation :geocode_address, on: :create

  def self.geocode!(address)
    # Try to find by exact user input
    found = find_by(address: address)
    return found if found

    # If not found, geocode and create new record
    result = GoogleMapsService.instance.geocode(address)
    
    create!(
      address: address,  # Keep original user input
      location: "POINT(#{result[:lng]} #{result[:lat]})"
    )
  end

  private

  def geocode_address
    return if address.blank?

    begin
      result = GoogleMapsService.instance.geocode(address)
      self.location = "POINT(#{result[:lng]} #{result[:lat]})"
    rescue => e
      errors.add(:address, :invalid, message: e.message)
    end
  end
end

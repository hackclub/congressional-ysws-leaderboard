module Ysws
  class GeocodeProjectJob < ApplicationJob
    queue_as :default

    def perform(project_id, address_to_geocode)
      # Find or geocode the address and get its location and district ID
      location = nil
      district_id = nil
      address_record = nil

      begin
        if address_to_geocode.present?
          # Use the updated method that finds/geocodes and sets the district
          address_record = Address.find_or_geocode_and_set_district!(address_to_geocode)
          location = address_record&.location
          district_id = address_record&.congressional_district_id
        end
      rescue Address::GeocodeError => e
        # Log geocoding errors, but proceed to update project with nil location/district
        Rails.logger.warn "Failed to find or geocode address for project #{project_id}: #{e.message}"
      end

      # Update the project's location and congressional_district_id
      # Use the values obtained from the address_record
      Ysws::Project.where(airtable_id: project_id).update_all(
        location: location,
        congressional_district_id: district_id
      )
    end
  end
end 
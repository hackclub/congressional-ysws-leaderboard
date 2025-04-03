module Ysws
  class GeocodeProjectJob < ApplicationJob
    queue_as :default

    def perform(project_id, address_to_geocode)
      # Try to geocode, but leave location as nil if it fails
      location = nil
      begin
        if address_to_geocode.present?
          address = Address.geocode!(address_to_geocode)
          location = address.location
        end
      rescue Address::GeocodeError => e
        Rails.logger.warn "Failed to geocode address for project #{project_id}: #{e.message}"
      end

      # Update the project's location
      Ysws::Project.where(airtable_id: project_id).update_all(location: location)
    end
  end
end 
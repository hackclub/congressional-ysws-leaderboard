module Ysws
  class SyncProjectsJob < ApplicationJob
    queue_as :default

    def perform
      airtable = AirtableService.instance
      offset = nil
      
      loop do
        response = airtable.list_records(
          Rails.application.credentials.airtable.ysws.table_id.approved_projects, 
          offset: offset
        )
        
        response["records"].each do |record|
          fields = sanitize_fields(record["fields"])

          # Construct address from various address fields
          address_components = []
          address_components << fields["Address (Line 1)"] if fields["Address (Line 1)"].present?
          address_components << fields["City"] if fields["City"].present?
          address_components << fields["State / Province"] if fields["State / Province"].present?
          address_components << fields["ZIP / Postal Code"] if fields["ZIP / Postal Code"].present?
          address_components << fields["Country"] if fields["Country"].present?
          
          address_to_geocode = address_components.compact.join(", ")
          
          # Try to find existing address first
          location = nil
          district_id = nil
          if address_to_geocode.present?
            existing_address = Address.find_by(address: address_to_geocode)
            if existing_address
              location = existing_address.location
              district_id = existing_address.congressional_district_id
            end
          end
          
          # Create/update the project
          Ysws::Project.upsert(
            {
              airtable_id: record["id"],
              fields: fields,
              location: location,
              congressional_district_id: district_id
            },
            unique_by: :airtable_id
          )

          # Only queue geocoding if we have an address and it wasn't found
          if address_to_geocode.present? && location.nil?
            GeocodeProjectJob.perform_later(record["id"], address_to_geocode)
          end
        end

        offset = response["offset"]
        break unless offset
      end
    end

    private

    def sanitize_fields(fields)
      fields.transform_values do |value|
        case value
        when String
          value.delete("\u0000")  # Remove null bytes
        when Array
          value.map { |v| v.is_a?(String) ? v.delete("\u0000") : v }
        else
          value
        end
      end
    end
  end
end 
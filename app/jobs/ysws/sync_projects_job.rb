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
          
          # Extract lat/lng from address if available
          location = if fields["Geocoded Location"]
            lat = fields["Geocoded Location"]["lat"]
            lng = fields["Geocoded Location"]["lng"]
            "POINT(#{lng} #{lat})"
          end

          Ysws::Project.upsert(
            {
              airtable_id: record["id"],
              fields: fields,
              location: location
            },
            unique_by: :airtable_id
          )
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
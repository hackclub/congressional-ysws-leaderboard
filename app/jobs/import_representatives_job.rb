require 'httpx'
require 'json'
require 'date'
require 'uri'

class ImportRepresentativesJob < ApplicationJob
  queue_as :default

  # Helper Function to Get Wikipedia Image
  private def get_wikipedia_image_url(page_title)
    return nil unless page_title.present?

    # Encode the title for the URL
    encoded_title = URI.encode_www_form_component(page_title)
    wiki_api_url = "https://en.wikipedia.org/w/api.php?action=query&titles=#{encoded_title}&prop=pageimages&format=json&pithumbsize=300"

    begin
      wiki_response = HTTPX.plugin(:follow_redirects).get(wiki_api_url, timeout: {request_timeout: 10}) # Shorter timeout for Wiki API
      wiki_response.raise_for_status
      wiki_data = JSON.parse(wiki_response.body.to_s)

      # Extract the URL - navigate through the dynamic page ID
      page_id = wiki_data.dig('query', 'pages')&.keys&.first
      thumbnail_url = wiki_data.dig('query', 'pages', page_id, 'thumbnail', 'source')

      return thumbnail_url.presence # Return nil if URL is blank
    rescue HTTPX::Error, JSON::ParserError => e
      Rails.logger.warn("Could not fetch/parse Wikipedia image for '#{page_title}': #{e.message}")
      return nil
    end
  end

  def perform(*args)
    legislators_url = "https://unitedstates.github.io/congress-legislators/legislators-current.json"
    updated_count = 0
    not_found_count = 0
    skipped_count = 0
    image_fetch_failed_count = 0

    Rails.logger.info("Starting ImportRepresentativesJob: Downloading legislator data from #{legislators_url}...")

    begin
      response = HTTPX.plugin(:follow_redirects).get(legislators_url, timeout: {request_timeout: 30})
      response.raise_for_status
      legislators_data = JSON.parse(response.body.to_s)
      Rails.logger.info("Download complete. Processing data...")

    rescue HTTPX::Error => e
      Rails.logger.error("Error downloading legislator data: #{e.message}")
      if e.respond_to?(:response) && e.response
        Rails.logger.error("Response status: #{e.response.status}")
        Rails.logger.error("Response body: #{e.response.body.to_s[0..500]}...")
      end
      # Optionally re-raise or handle the error appropriately for the job
      raise e # Re-raise to mark the job as failed
    rescue JSON::ParserError => e
      Rails.logger.error("Error parsing legislator JSON data: #{e.message}")
      raise e # Re-raise to mark the job as failed
    end

    legislators_data.each_with_index do |legislator, index|
        # Find the current term where type is 'rep'
        current_term = legislator['terms'].find do |t|
            t['type'] == 'rep' && (t['end'].nil? || (Date.parse(t['end']) > Date.today rescue false))
        end

        unless current_term
            skipped_count += 1
            next
        end

        state_abbrev = current_term['state']
        district_num = current_term['district']
        wikipedia_title = legislator.dig('id', 'wikipedia')
        bioguide_id = legislator.dig('id', 'bioguide')

        unless state_abbrev && !district_num.nil? && (wikipedia_title.present? || bioguide_id.present?)
            unless ['AS', 'GU', 'MP', 'PR', 'VI'].include?(state_abbrev)
                Rails.logger.warn("Skipping legislator due to missing state/district/id: #{legislator.dig('name','official_full')} State: #{state_abbrev}, District: #{district_num}, Wiki: #{wikipedia_title}, BioGuide: #{bioguide_id}")
            end
            skipped_count += 1
            next
        end

        full_name = legislator.dig('name', 'official_full') || "#{legislator.dig('name', 'first')} #{legislator.dig('name', 'last')}".strip
        party = current_term['party']

        picture_url = get_wikipedia_image_url(wikipedia_title)
        if picture_url.nil?
            image_fetch_failed_count += 1
            Rails.logger.info("Using fallback image for #{full_name} (BioGuide: #{bioguide_id})")
            picture_url = "https://theunitedstates.io/images/congress/225x275/#{bioguide_id}.jpg" if bioguide_id.present?
        end

        db_district_num = (state_abbrev == 'DC' && district_num == 0) ? 98 : district_num

        district = CongressionalDistrict.find_by(state: state_abbrev, district_number: db_district_num)

        if district
            begin
                if district.representative_name != full_name || district.representative_party != party || district.representative_picture_url != picture_url
                    district.update!(
                        representative_name: full_name,
                        representative_party: party,
                        representative_picture_url: picture_url
                    )
                    updated_count += 1
                end
            rescue ActiveRecord::RecordInvalid => e
                Rails.logger.error("Validation error updating district #{state_abbrev}-#{db_district_num}: #{e.message} Data: #{ { name: full_name, party: party, url: picture_url } }")
                not_found_count += 1
            rescue => e
                Rails.logger.error("Error updating district #{state_abbrev}-#{db_district_num}: #{e.message}")
                not_found_count += 1
            end
        else
            unless ['AS', 'GU', 'MP', 'PR', 'VI'].include?(state_abbrev)
                Rails.logger.warn("District not found in DB for #{state_abbrev}-#{db_district_num} (Source District: #{district_num}) - Rep: #{full_name}")
            end
            not_found_count += 1
        end

        # Optional: Add a small delay
        sleep(0.05) if index > 0 && index % 20 == 0
    end

    Rails.logger.info("Finished ImportRepresentativesJob.")
    Rails.logger.info("Updated #{updated_count} districts.")
    Rails.logger.info("#{image_fetch_failed_count} representatives had failed Wikipedia image lookups (used fallback).")
    Rails.logger.info("#{not_found_count} representatives from source not matched/updated in the database (includes territories and errors).")
    Rails.logger.info("Skipped #{skipped_count} entries (non-representatives, non-current terms, territories, or missing data).")

  end
end

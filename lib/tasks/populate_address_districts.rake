namespace :address do
  desc "Populate congressional_district_id for existing Address records with locations"
  task populate_districts: :environment do
    puts "Starting to populate congressional_district_id for Addresses..."

    updated_count = 0
    not_found_count = 0

    Address.where.not(location: nil).where(congressional_district_id: nil).find_each do |address|
      district = CongressionalDistrict.find_by_location(address.location)
      
      if district
        address.update_column(:congressional_district_id, district.id)
        updated_count += 1
        print '.' if updated_count % 100 == 0 # Progress indicator
      else
        not_found_count += 1
        # Optional: Log addresses that couldn't be matched to a district
        # Rails.logger.warn "Could not find district for Address #{address.id}"
        print 'x' if not_found_count % 100 == 0 
      end
    end

    puts "\nFinished populating Addresses."
    puts "Updated records: #{updated_count}"
    puts "Records where district not found: #{not_found_count}"
  end
end 